import SwiftUI
import ZotEatsKit

// Busyness screen — live campus occupancy grouped by category, with
// expandable sub-location breakdowns for facilities that report zones.

struct BusynessView: View {
    let store: BusynessStore
    @Binding var pendingDeepLink: AnteatsDeepLink?
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    /// Facility to expand/scroll to from Quietest widget / Dining tip.
    @State private var deepLinkFacilityID: Int?
    /// Bumps on each Study facility deep link so warm re-taps re-expand floors.
    @State private var expandPulse: Int = 0
    /// Bumps after each Quietest / Waitz tick so hero + crowding re-render.
    @State private var boundaryEpoch = 0

    private static let categoryOrder = ["Library", "Recreation", "Dining", "Campus"]

    private var boundaryWatchID: String {
        let openKey = store.facilities.value.map {
            StudyBoundaryRefresh.anyLibraryOpen(from: $0) ? "open" : "closed"
        } ?? "nil"
        return "\(boundaryEpoch)|\(openKey)"
    }

    // No NavigationStack: nothing navigates, and a flat hierarchy lets the
    // iOS 26 glass tab bar track this scroll view directly (minimize-on-scroll).
    var body: some View {
        let _ = boundaryEpoch
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Study", subtitle: "Where it’s calm right now", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable {
                await store.load()
                boundaryEpoch += 1
            }
            .statusBarBackdrop()
            .task {
                await store.load()
                // Failed feeds leave facilities.value nil — still settle pending links.
                applyPendingDeepLinkIfNeeded()
                scrollToDeepLinkedFacility(proxy: proxy)
            }
            .task(id: boundaryWatchID) {
                await watchLibraryBoundaries()
            }
            .onChange(of: store.facilities.value) {
                applyPendingDeepLinkIfNeeded()
                scrollToDeepLinkedFacility(proxy: proxy)
            }
            .onChange(of: pendingDeepLink) {
                applyPendingDeepLinkIfNeeded()
                scrollToDeepLinkedFacility(proxy: proxy)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    boundaryEpoch += 1
                }
            }
            .onAppear {
                applyPendingDeepLinkIfNeeded()
                scrollToDeepLinkedFacility(proxy: proxy)
            }
        }
    }

    /// Sleep until the next occupancy tick (libraries open) or morning
    /// open / midnight (closed), then reload while Study stays open.
    private func watchLibraryBoundaries() async {
        guard let facilities = store.facilities.value else { return }
        let fire = StudyBoundaryRefresh.nextFire(facilities: facilities)
        let delay = fire.timeIntervalSinceNow
        if delay > 0.05 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        await store.load()
        boundaryEpoch += 1
    }

    private func applyPendingDeepLinkIfNeeded() {
        guard let link = pendingDeepLink, link.tab == .study else { return }
        let feedReady: Bool = {
            switch store.facilities {
            case .loaded, .failed: return true
            case .idle, .loading: return false
            }
        }()
        switch StudyDeepLinkApply.resolve(
            facilityID: link.facilityID,
            facilities: store.facilities.value,
            feedReady: feedReady
        ) {
        case .waitForFacilities:
            return
        case .discard:
            // Unknown / failed — drop pin so Quietest auto-expand can win again.
            deepLinkFacilityID = StudyFacilityExpand.pinAfterApplying(linkFacilityID: nil)
            pendingDeepLink = nil
        case .apply(let facilityID):
            deepLinkFacilityID = StudyFacilityExpand.pinAfterApplying(
                linkFacilityID: facilityID
            )
            if StudyFacilityExpand.shouldExpandPulse(linkFacilityID: facilityID) {
                expandPulse += 1
            }
            pendingDeepLink = nil
        }
    }

    private func scrollToDeepLinkedFacility(proxy: ScrollViewProxy) {
        guard let id = deepLinkFacilityID else { return }
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.35)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.facilities {
        case .idle, .loading:
            VStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(height: 128)
                }
            }
        case .failed(let message):
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: "Couldn't load busyness",
                message: message,
                retry: { Task { await store.load() } }
            )
            .zotCard()
        case .loaded(let facilities):
            if facilities.isEmpty {
                EmptyStateView(
                    icon: "ant",
                    title: "All quiet",
                    message: "No spots are reporting right now. Even the ants went home.",
                    retry: { Task { await store.load() } }
                )
                .zotCard()
            } else {
                let pick = QuietestLibraryPick.best(from: facilities)
                if let pick {
                    QuietestNowCard(pick: pick)
                } else if QuietestLibraryGlance.shouldShowClosed(from: facilities) {
                    QuietestClosedCard(
                        reopenMinutes: StudyIdleCopy.soonestReopenMinutes(from: facilities)
                    )
                }
                let expandID = StudyFacilityExpand.targetID(
                    pendingFacilityID: StudyFacilityExpand.pendingFacilityID(from: pendingDeepLink),
                    deepLinkFacilityID: deepLinkFacilityID,
                    quietestFacilityID: pick?.facilityID
                )
                let grouped = groups(from: facilities)
                if !store.libraryHours.isEmpty {
                    LibraryHoursTodayCard(hours: store.libraryHours)
                }
                StudentCenterStudyCard()
                ForEach(grouped, id: \.category) { group in
                    // A lone "Library" header under a tab named Study is noise;
                    // headers earn their place only when multiple categories report.
                    BusynessGroupSection(
                        category: group.category,
                        facilities: group.facilities,
                        showHeader: grouped.count > 1,
                        expandFacilityID: expandID,
                        expandPulse: expandPulse,
                        libraryHours: store.libraryHours
                    )
                }
            }
        }
    }

    /// Groups facilities by category in fixed order, sorting each group
    /// open-first then by percent descending (nil percent last).
    private func groups(from facilities: [BusynessPoint])
        -> [(category: String, facilities: [BusynessPoint])] {
        let nowMinutes = UCITime.nowMinutes()
        return Self.categoryOrder.compactMap { category in
            let members = facilities
                .filter { $0.category == category }
                .sorted { lhs, rhs in
                    let lhsOpen = lhs.isEffectivelyOpen(nowMinutes: nowMinutes)
                    let rhsOpen = rhs.isEffectivelyOpen(nowMinutes: nowMinutes)
                    if lhsOpen != rhsOpen { return lhsOpen }
                    switch (lhs.percent, rhs.percent) {
                    case (let l?, let r?): return l > r
                    case (.some, .none): return true
                    case (.none, .some): return false
                    case (.none, .none): return false
                    }
                }
            return members.isEmpty ? nil : (category, members)
        }
    }
}

// MARK: - "Quietest right now" recommendation card

struct QuietestNowCard: View {
    let pick: QuietestLibraryPick

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.uciGold)
                .frame(width: 40, height: 40)
                .background(
                    Color.uciGold.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("QUIETEST RIGHT NOW")
                    .font(ZotFont.face(10, relativeTo: .caption2).weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(Color.inkMuted)
                Text(pick.title)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(spacing: 1) {
                Text("\(pick.percent)%")
                    .font(ZotFont.face(22, relativeTo: .title2).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                Text("full")
                    .font(ZotFont.face(10, relativeTo: .caption2))
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.ink.opacity(0.08),
                    Color.uciGold.opacity(0.07),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                .strokeBorder(Color.ink.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            QuietestLibraryAccessibilityLabel.label(
                name: pick.title,
                percent: pick.percent,
                includeQuietestQualifier: true,
                updatedRelative: UpdatedAgoCopy.relative(from: pick.updatedAt)
            )
        )
    }
}

/// Honest overnight / closed hero — matches Quietest widget "Libraries closed".
struct QuietestClosedCard: View {
    var reopenMinutes: Int? = nil

    private var detail: String {
        StudyIdleCopy.quietestClosedDetail(reopenMinutes: reopenMinutes)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 40, height: 40)
                .background(
                    Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("QUIETEST RIGHT NOW")
                    .font(ZotFont.face(10, relativeTo: .caption2).weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(Color.inkMuted)
                Text(QuietestLibraryGlance.closedTitle)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(ZotFont.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.card,
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(QuietestLibraryGlance.closedTitle). \(detail)")
    }
}

/// Soft today-hours strip for Langson + Science — LibCal clocks Waitz doesn't give.
/// Matches Study glance chrome (not another stacked white card with Open pills).
private struct LibraryHoursTodayCard: View {
    let hours: [LibraryBuildingHours]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today’s hours")
                .font(ZotFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.element.id) { index, building in
                    if index > 0 {
                        Capsule()
                            .fill(Color.inkMuted.opacity(0.35))
                            .frame(width: 2)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 14)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(building.shortName)
                                .font(ZotFont.body.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            Text(building.isOpen ? "Open" : "Closed")
                                .font(ZotFont.caption.weight(.semibold))
                                .foregroundStyle(building.isOpen ? Color.openGreen : .secondary)
                        }
                        Text(building.rendered)
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(building.shortName), \(building.isOpen ? "open" : "closed"), \(building.rendered)"
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
    }
}

/// Hours-only Student Center study spaces — no fake Occuspace % while they recalibrate.
private struct StudentCenterStudyCard: View {
    private var spaces: [StudentCenterStudyHours.Space] {
        StudentCenterStudyHours.spaces()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Student Center")
                .font(ZotFont.caption.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
                .textCase(.uppercase)
                .tracking(0.4)
                .accessibilityAddTraits(.isHeader)

            ForEach(spaces) { space in
                HStack(spacing: 8) {
                    Circle()
                        .fill(space.isOpen ? Color.openGreen : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)
                    Text(shortName(space.name))
                        .font(ZotFont.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(space.hours)
                        .font(ZotFont.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(space.name), \(space.location), \(space.isOpen ? "open" : "closed"), \(space.hours)"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
    }

    private func shortName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " Study Lounge", with: "")
            .replacingOccurrences(of: " Lounge", with: "")
    }
}

// MARK: - Category section

struct BusynessGroupSection: View {
    let category: String
    let facilities: [BusynessPoint]
    var showHeader = true
    /// Auto-expand the quietest library’s floors when Study recommends it.
    var expandFacilityID: Int? = nil
    /// Increments on facility deep links so warm re-taps re-expand collapsed floors.
    var expandPulse: Int = 0
    var libraryHours: [LibraryBuildingHours] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader {
                Text(category)
                    .font(ZotFont.sectionTitle)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }

            ForEach(facilities) { facility in
                BusynessFacilityCard(
                    facility: facility,
                    initiallyExpanded: expandFacilityID == facility.id,
                    expandPulse: expandFacilityID == facility.id ? expandPulse : 0,
                    libraryHours: LibraryHoursMatch.hours(
                        forFacilityName: facility.name,
                        from: libraryHours
                    )
                )
                .id(facility.id)
            }
        }
    }
}

// MARK: - Facility card

struct BusynessFacilityCard: View {
    let facility: BusynessPoint
    var initiallyExpanded: Bool = false
    var expandPulse: Int = 0
    var libraryHours: LibraryBuildingHours? = nil
    @State private var isExpanded = false

    /// Floors/zones after Lobby filtering + floor grouping.
    private var floors: [BusynessFloorGroup] {
        BusynessFloorGrouping.floors(from: facility.subLocations)
    }

    private var hasFloors: Bool { !floors.isEmpty }

    private var effectivelyOpen: Bool {
        facility.isEffectivelyOpen(nowMinutes: UCITime.nowMinutes())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(facility.name)
                        .font(ZotFont.cardTitle)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    StatusPill(isOpen: effectivelyOpen)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen),
                       let percent = facility.percent {
                        Text("\(percent)%")
                            .font(ZotFont.face(28, relativeTo: .title).weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(facility.level.color)
                        Text(facility.level.label)
                            .font(ZotFont.pill)
                            .foregroundStyle(facility.level.color)
                    } else if StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen) {
                        Text("—")
                            .font(ZotFont.face(28, relativeTo: .title).weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(facility.level.label)
                            .font(ZotFont.pill)
                            .foregroundStyle(facility.level.color)
                    } else {
                        Text("—")
                            .font(ZotFont.face(28, relativeTo: .title).weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(StudyFacilityCrowding.closedLevelLabel)
                            .font(ZotFont.pill)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen) {
                    OccupancyBar(percent: facility.percent, level: facility.level)
                    if let openLine = StudyIdleCopy.facilityOpenDetail(
                        hoursSummary: facility.hoursSummary,
                        libraryHours: libraryHours
                    ) {
                        Text(openLine)
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(
                        StudyIdleCopy.facilityClosedDetail(
                            hoursSummary: facility.hoursSummary,
                            libraryHours: libraryHours
                        )
                    )
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen),
                       let count = facility.count, let capacity = facility.capacity {
                        Text("\(count) / \(capacity) people")
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    UpdatedAgoText(date: facility.updatedAt)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                StudyFacilityAccessibilityLabel.label(
                    name: facility.name,
                    isOpen: effectivelyOpen,
                    percent: facility.percent,
                    levelLabel: facility.level.label,
                    peopleCount: facility.count,
                    capacity: facility.capacity,
                    updatedRelative: UpdatedAgoCopy.relative(from: facility.updatedAt),
                    hoursSummary: facility.hoursSummary
                )
            )

            // Floor % goes stale overnight — only expand while the building is open.
            if hasFloors, StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen) {
                expandToggle
                if isExpanded {
                    floorsList
                }
            }
        }
        .padding(16)
        .zotCard()
        .onAppear {
            expandIfRequested()
        }
        .onChange(of: initiallyExpanded) { _, shouldExpand in
            if shouldExpand { expandIfRequested() }
        }
        .onChange(of: expandPulse) { _, _ in
            if initiallyExpanded { expandIfRequested() }
        }
    }

    private func expandIfRequested() {
        guard initiallyExpanded,
              hasFloors,
              StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen),
              !isExpanded
        else { return }
        withAnimation(.snappy(duration: 0.3)) {
            isExpanded = true
        }
    }

    private var floorsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(floors) { floor in
                BusynessFloorBlock(floor: floor)
            }
        }
        .transition(.opacity)
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                isExpanded.toggle()
            }
            Haptics.selection()
        } label: {
            // Collapsed = chevron.down (“more”); expanded = chevron.up. No
            // rotation games — and this toggle only renders when expandable.
            HStack(spacing: 6) {
                Text(isExpanded ? "Hide floors" : "\(floors.count) floors")
                    .font(ZotFont.pill.weight(.semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(width: 18, height: 18)
            }
            .foregroundStyle(Color.ink)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isExpanded
                ? "Hide floors inside \(facility.name)"
                : "Show floors inside \(facility.name)"
        )
    }
}

// MARK: - Floor group + zone rows

/// One floor in the expand list. Multi-zone floors get a header + short
/// zone names; a lone "1st Floor" / "Basement" stays a single row.
private struct BusynessFloorBlock: View {
    let floor: BusynessFloorGroup

    private var isFlatFloor: Bool {
        floor.zones.count == 1 && floor.zones[0].displayName == floor.floorLabel
    }

    var body: some View {
        if isFlatFloor, let zone = floor.zones.first {
            BusynessZoneRowView(zone: zone)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(floor.floorLabel)
                    .font(ZotFont.face(11, relativeTo: .caption2).weight(.medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 6) {
                    ForEach(floor.zones) { zone in
                        BusynessZoneRowView(zone: zone)
                    }
                }
            }
        }
    }
}

struct BusynessZoneRowView: View {
    let zone: BusynessZoneRow

    var body: some View {
        HStack(spacing: 10) {
            Text(zone.displayName)
                .font(ZotFont.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            OccupancyBar(percent: zone.percent, level: zone.level, height: 6)
                .frame(width: 72)

            Text(zone.percent.map { "\($0)%" } ?? "—")
                .font(ZotFont.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(zone.level.color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            StudyZoneAccessibilityLabel.label(
                fullName: zone.fullName,
                percent: zone.percent,
                levelLabel: zone.level.label
            )
        )
    }
}

// MARK: - Previews (fixture data only; no network)

#Preview("Facility cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Study", subtitle: "Where it’s calm right now")
            VStack(alignment: .leading, spacing: 16) {
                BusynessGroupSection(
                    category: "Library",
                    facilities: [
                        BusynessPoint(
                            id: 1,
                            name: "Langson Library",
                            category: "Library",
                            count: 480,
                            capacity: 600,
                            percent: 80,
                            level: .veryBusy,
                            isOpen: true,
                            hoursSummary: nil,
                            updatedAt: Date().addingTimeInterval(-120),
                            subLocations: [
                                BusynessPoint(
                                    id: 11, name: "1st Floor", category: "Library",
                                    count: nil, capacity: nil, percent: 12, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 12, name: "2nd Floor - Holden Room", category: "Library",
                                    count: nil, capacity: nil, percent: 15, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 13, name: "2nd Floor - Open Seating", category: "Library",
                                    count: nil, capacity: nil, percent: 26, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 14, name: "3rd Floor - Collaboration Zone", category: "Library",
                                    count: nil, capacity: nil, percent: 17, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 15, name: "3rd Floor - Open Seating", category: "Library",
                                    count: nil, capacity: nil, percent: 12, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                            ]
                        ),
                        BusynessPoint(
                            id: 2,
                            name: "Science Library",
                            category: "Library",
                            count: 120,
                            capacity: 800,
                            percent: 15,
                            level: .notBusy,
                            isOpen: true,
                            hoursSummary: nil,
                            updatedAt: Date().addingTimeInterval(-300),
                            subLocations: [
                                BusynessPoint(
                                    id: 21, name: "2nd Floor - Grand Reading Room", category: "Library",
                                    count: nil, capacity: nil, percent: 9, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 22, name: "2nd Floor - Active Study Zone", category: "Library",
                                    count: nil, capacity: nil, percent: 9, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 23, name: "Lobby", category: "Library",
                                    count: nil, capacity: nil, percent: 15, level: .notBusy,
                                    isOpen: true, hoursSummary: nil, updatedAt: Date(),
                                    subLocations: nil
                                ),
                            ]
                        ),
                    ]
                )
                BusynessGroupSection(
                    category: "Recreation",
                    facilities: [
                        BusynessPoint(
                            id: 3,
                            name: "ARC",
                            category: "Recreation",
                            count: nil,
                            capacity: nil,
                            percent: nil,
                            level: .unknown,
                            isOpen: false,
                            hoursSummary: nil,
                            updatedAt: Date().addingTimeInterval(-3600),
                            subLocations: nil
                        )
                    ]
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    .background(Color.screen)
}

#Preview("Empty") {
    EmptyStateView(
        icon: "moon.zzz",
        title: "All quiet",
        message: "No facilities are reporting right now.",
        retry: nil
    )
    .zotCard()
    .padding(20)
    .background(Color.screen)
}
