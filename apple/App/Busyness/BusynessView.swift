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

    /// Libraries only — gym / dining / campus lounges stay off this tab.
    private static let categoryOrder = ["Library"]

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
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Study", subtitle: "Where it’s calm right now", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
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

    /// Sleep until morning open / midnight / Waitz cadence, then reload — same
    /// honesty as the Quietest Library widget while Study stays open.
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
            // Unknown / failed — drop pin so a later Quietest tap isn't stuck
            // on a stale closed library.
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

    private func focusLibrary(_ facilityID: Int) {
        deepLinkFacilityID = facilityID
        expandPulse += 1
        Haptics.selection()
    }

    @ViewBuilder
    private var content: some View {
        switch store.facilities {
        case .idle, .loading:
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: 88)
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
            let libraries = StudyLibraryName.studyLibraries(from: facilities)
            if libraries.isEmpty {
                EmptyStateView(
                    icon: "ant",
                    title: "All quiet",
                    message: "No spots are reporting right now. Even the ants went home.",
                    retry: { Task { await store.load() } }
                )
                .zotCard()
            } else {
                let pick = QuietestLibraryPick.best(from: libraries)
                if let pick {
                    QuietestNowCard(pick: pick) {
                        if let id = pick.facilityID {
                            focusLibrary(id)
                        }
                    }
                } else if QuietestLibraryGlance.shouldShowClosed(from: libraries) {
                    QuietestClosedCard(
                        reopenMinutes: StudyIdleCopy.soonestReopenMinutes(from: libraries)
                    )
                }
                let expandID = StudyFacilityExpand.targetID(
                    pendingFacilityID: StudyFacilityExpand.pendingFacilityID(from: pendingDeepLink),
                    deepLinkFacilityID: deepLinkFacilityID,
                    quietestFacilityID: pick?.facilityID
                )
                let grouped = groups(from: libraries)
                ForEach(grouped, id: \.category) { group in
                    // A lone "Library" header under a tab named Study is noise;
                    // headers earn their place only when multiple categories report.
                    BusynessGroupSection(
                        category: group.category,
                        facilities: group.facilities,
                        showHeader: grouped.count > 1,
                        expandFacilityID: expandID,
                        expandPulse: expandPulse,
                        libraryHours: store.libraryHours,
                        cardSpacing: 12
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
                .filter { $0.category == category && StudyLibraryName.isStudyLibrary($0.name) }
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
    var onOpenFloors: (() -> Void)? = nil

    var body: some View {
        Button {
            onOpenFloors?()
        } label: {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.accent)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quietest right now")
                    .font(ZotFont.kicker)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkMuted)
                Text(pick.title)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(pick.percent)%")
                    .font(ZotFont.face(24, relativeTo: .title2).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                Text("full")
                    .font(ZotFont.kicker)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpenFloors == nil)
        .accessibilityHint(onOpenFloors == nil ? "" : "Shows floors inside \(pick.title)")
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Quietest right now")
                .font(ZotFont.kicker)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            Text(QuietestLibraryGlance.closedTitle)
                .font(ZotFont.cardTitle)
                .foregroundStyle(Color.ink)
            Text(detail)
                .font(ZotFont.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(QuietestLibraryGlance.closedTitle). \(detail)")
    }
}

// MARK: - Category section

struct BusynessGroupSection: View {
    let category: String
    let facilities: [BusynessPoint]
    var showHeader = true
    /// Deep-link facility to expand. Quietest never auto-opens floors.
    var expandFacilityID: Int? = nil
    /// Increments on facility deep links so warm re-taps re-expand collapsed floors.
    var expandPulse: Int = 0
    var libraryHours: [LibraryBuildingHours] = []
    var cardSpacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            if showHeader {
                Text(category)
                    .font(ZotFont.sectionTitle)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.inkMuted)
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

    private var canRevealFloors: Bool {
        StudyLibraryTap.canRevealFloors(hasFloors: hasFloors, isOpen: effectivelyOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Whole header is the tap target — never gated on open/closed.
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
                Haptics.selection()
            } label: {
                facilitySummary
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                isExpanded
                    ? "Hides floors inside \(StudyLibraryName.display(facility.name))"
                    : "Shows floors inside \(StudyLibraryName.display(facility.name))"
            )
            .accessibilityLabel(
                isExpanded
                    ? "Hide floors inside \(StudyLibraryName.display(facility.name))"
                    : "Show floors inside \(StudyLibraryName.display(facility.name))"
            )

            if isExpanded {
                if canRevealFloors {
                    floorsList
                } else {
                    floorsEmptyState
                }
            }
        }
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

    private var hoursLine: String? {
        StudyLibraryCardHours.line(
            isOpen: effectivelyOpen,
            hoursSummary: facility.hoursSummary,
            libraryHours: libraryHours
        )
    }

    private var facilitySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(StudyLibraryName.display(facility.name))
                    .font(ZotFont.cardTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                StatusPill(isOpen: effectivelyOpen)
                Image(systemName: ExpandChevron.systemName(isExpanded: isExpanded))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }

            if StudyFacilityCrowding.showsLiveCrowding(isOpen: effectivelyOpen) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let percent = facility.percent {
                        Text("\(percent)%")
                            .font(ZotFont.face(20, relativeTo: .title3).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(facility.level.color)
                        Text(facility.level.label)
                            .font(ZotFont.pill)
                            .foregroundStyle(facility.level.color)
                    } else {
                        Text("—")
                            .font(ZotFont.face(20, relativeTo: .title3).weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(facility.level.label)
                            .font(ZotFont.pill)
                            .foregroundStyle(facility.level.color)
                    }
                    Spacer(minLength: 8)
                    if let hoursLine {
                        Text(hoursLine)
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                OccupancyBar(percent: facility.percent, level: facility.level, height: 6)
            } else if let hoursLine {
                Text(hoursLine)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                expandToggle
                Spacer(minLength: 8)
                UpdatedAgoText(date: facility.updatedAt)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .frame(minHeight: 44, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
        .accessibilityLabel(
            StudyFacilityAccessibilityLabel.label(
                name: StudyLibraryName.display(facility.name),
                isOpen: effectivelyOpen,
                percent: facility.percent,
                levelLabel: facility.level.label,
                peopleCount: facility.count,
                capacity: facility.capacity,
                updatedRelative: UpdatedAgoCopy.relative(from: facility.updatedAt),
                hoursSummary: facility.hoursSummary,
                libraryHours: libraryHours
            )
        )
    }

    /// Deep-link / Quietest tap still expands. Never auto-opens on first entry.
    private func expandIfRequested() {
        guard initiallyExpanded, !isExpanded else { return }
        withAnimation(.snappy(duration: 0.3)) {
            isExpanded = true
        }
    }

    private var floorsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZotHairline(leading: 16)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(floors) { floor in
                    BusynessFloorBlock(floor: floor, embedded: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .transition(.opacity)
    }

    private var floorsEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZotHairline(leading: 16)
            Text(StudyLibraryTap.expandedEmptyDetail(isOpen: effectivelyOpen))
            .font(ZotFont.caption)
            .foregroundStyle(Color.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
        .accessibilityLabel(
            StudyLibraryTap.expandedEmptyDetail(isOpen: effectivelyOpen)
        )
    }

    private var expandToggle: some View {
        // Count hint only — chevron lives on the header row (right/down).
        Text(StudyLibraryTap.floorsHint(floorCount: floors.count, isExpanded: isExpanded))
            .font(ZotFont.pill.weight(.semibold))
            .foregroundStyle(Color.ink)
            .accessibilityHidden(true)
    }
}

// MARK: - Floor group + zone rows

/// One floor in the expand list. Multi-zone floors get a header + short
/// zone names; a lone "1st Floor" / "Basement" stays a single row.
private struct BusynessFloorBlock: View {
    let floor: BusynessFloorGroup
    var embedded = false

    private var isFlatFloor: Bool {
        floor.zones.count == 1 && floor.zones[0].displayName == floor.floorLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !isFlatFloor {
                Text(floor.floorLabel)
                    .font(ZotFont.kicker)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleZones.enumerated()), id: \.element.id) { index, zone in
                    if index > 0 {
                        ZotHairline(leading: StudyZonePillMark.horizontalPadding)
                    }
                    BusynessZoneRowView(zone: zone, embedded: true)
                        .padding(.leading, isFlatFloor ? 0 : StudyZonePillMark.floorIndent)
                }
            }
            .padding(.vertical, 4)
            .background(Color.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, embedded ? 4 : 0)
    }

    private var visibleZones: [BusynessZoneRow] {
        floor.zones
    }
}

struct BusynessZoneRowView: View {
    let zone: BusynessZoneRow
    var embedded = false

    var body: some View {
        HStack(alignment: .center, spacing: StudyZonePillMark.namePercentSpacing) {
            Text(zone.displayName)
                .font(ZotFont.cardTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

            OccupancyBar(percent: zone.percent, level: zone.level, height: 6)
                .frame(width: StudyZonePillMark.barWidth)
                .layoutPriority(0)

            Text(zone.percent.map { "\($0)%" } ?? "—")
                .font(ZotFont.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(zone.level.color)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: StudyZonePillMark.percentMinWidth, alignment: .trailing)
                .layoutPriority(1)
        }
        .padding(.leading, StudyZonePillMark.horizontalPadding)
        .padding(.trailing, StudyZonePillMark.trailingPadding)
        .padding(.vertical, embedded ? StudyZonePillMark.verticalPadding : 14)
        .modifier(EmbeddedOrCard(embedded: embedded))
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

private struct EmbeddedOrCard: ViewModifier {
    var embedded: Bool

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content.zotCard()
        }
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
    .appCanvas()
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
    .appCanvas()
}
