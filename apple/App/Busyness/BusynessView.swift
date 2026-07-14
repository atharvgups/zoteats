import SwiftUI
import ZotEatsKit

// Busyness screen — live campus occupancy grouped by category, with
// expandable sub-location breakdowns for facilities that report zones.

struct BusynessView: View {
    @State private var store = BusynessStore()
    @Environment(\.openSettings) private var openSettings

    private static let categoryOrder = ["Library", "Recreation", "Dining", "Campus"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Study", subtitle: "Find a quiet library spot", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.screen)
            .refreshable { await store.load() }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarBackdrop()
        }
        .task { await store.load() }
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
                if let pick = Self.quietestPick(facilities) {
                    QuietestNowCard(facility: pick)
                }
                let grouped = groups(from: facilities)
                ForEach(grouped, id: \.category) { group in
                    // A lone "Library" header under a tab named Study is noise;
                    // headers earn their place only when multiple categories report.
                    BusynessGroupSection(
                        category: group.category,
                        facilities: group.facilities,
                        showHeader: grouped.count > 1
                    )
                }
            }
        }
    }

    /// The emptiest open facility right now — an actionable recommendation,
    /// not just data. Requires a known percent to qualify.
    static func quietestPick(_ facilities: [BusynessPoint]) -> BusynessPoint? {
        facilities
            .filter { $0.isOpen && $0.percent != nil }
            .min { ($0.percent ?? 101) < ($1.percent ?? 101) }
    }

    /// Groups facilities by category in fixed order, sorting each group
    /// open-first then by percent descending (nil percent last).
    private func groups(from facilities: [BusynessPoint])
        -> [(category: String, facilities: [BusynessPoint])] {
        Self.categoryOrder.compactMap { category in
            let members = facilities
                .filter { $0.category == category }
                .sorted { lhs, rhs in
                    if lhs.isOpen != rhs.isOpen { return lhs.isOpen }
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
    let facility: BusynessPoint

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.uciGold)
                .frame(width: 38, height: 38)
                .background(Color.uciGold.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("QUIETEST RIGHT NOW")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text(facility.name)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            if let percent = facility.percent {
                VStack(spacing: 0) {
                    Text("\(percent)%")
                        .font(.system(size: 21, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.uciBlue)
                    Text("full")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.uciBlue.opacity(0.06),
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                .strokeBorder(Color.uciBlue.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Quietest right now: \(facility.name)\(facility.percent.map { ", \($0) percent full" } ?? "")"
        )
    }
}

// MARK: - Category section

struct BusynessGroupSection: View {
    let category: String
    let facilities: [BusynessPoint]
    var showHeader = true

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
                BusynessFacilityCard(facility: facility)
            }
        }
    }
}

// MARK: - Facility card

struct BusynessFacilityCard: View {
    let facility: BusynessPoint
    @State private var isExpanded = false

    private var hasSubLocations: Bool {
        !(facility.subLocations ?? []).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(facility.name)
                    .font(ZotFont.cardTitle)
                    .lineLimit(2)
                Spacer(minLength: 8)
                StatusPill(isOpen: facility.isOpen)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let percent = facility.percent {
                    Text("\(percent)%")
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(facility.level.color)
                } else {
                    Text("—")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Text(facility.level.label)
                    .font(ZotFont.pill)
                    .foregroundStyle(facility.level.color)
                Spacer()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(percentAccessibilityLabel)

            OccupancyBar(percent: facility.percent, level: facility.level)

            HStack {
                if let count = facility.count, let capacity = facility.capacity {
                    Text("\(count) / \(capacity) people")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UpdatedAgoText(date: facility.updatedAt)
            }

            if hasSubLocations {
                expandToggle
                if isExpanded, let subLocations = facility.subLocations {
                    VStack(spacing: 8) {
                        ForEach(subLocations) { sub in
                            BusynessSubLocationRow(point: sub)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                isExpanded.toggle()
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Text(isExpanded ? "Hide areas" : "\(facility.subLocations?.count ?? 0) areas")
                    .font(ZotFont.pill)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(Color.uciBlue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isExpanded
                ? "Hide areas inside \(facility.name)"
                : "Show areas inside \(facility.name)"
        )
    }

    private var percentAccessibilityLabel: String {
        if let percent = facility.percent {
            return "\(percent) percent full, \(facility.level.label)"
        }
        return facility.level.label
    }
}

// MARK: - Compact sub-location row

struct BusynessSubLocationRow: View {
    let point: BusynessPoint

    var body: some View {
        HStack(spacing: 10) {
            Text(point.name)
                .font(ZotFont.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            OccupancyBar(percent: point.percent, level: point.level, height: 6)
                .frame(width: 72)

            Text(point.percent.map { "\($0)%" } ?? "—")
                .font(ZotFont.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(point.level.color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            point.percent.map { "\(point.name), \($0) percent full" }
                ?? "\(point.name), no occupancy data"
        )
    }
}

// MARK: - Previews (fixture data only; no network)

#Preview("Facility cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Study", subtitle: "Find a quiet library spot")
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
                                    id: 11,
                                    name: "1st Floor",
                                    category: "Library",
                                    count: nil,
                                    capacity: nil,
                                    percent: 92,
                                    level: .veryBusy,
                                    isOpen: true,
                                    hoursSummary: nil,
                                    updatedAt: Date(),
                                    subLocations: nil
                                ),
                                BusynessPoint(
                                    id: 12,
                                    name: "2nd Floor",
                                    category: "Library",
                                    count: nil,
                                    capacity: nil,
                                    percent: 61,
                                    level: .busy,
                                    isOpen: true,
                                    hoursSummary: nil,
                                    updatedAt: Date(),
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
                            subLocations: nil
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
