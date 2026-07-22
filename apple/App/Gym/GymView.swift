import SwiftUI
import ZotEatsKit

// Gym screen: live Waitz occupancy when available, plus hours. Typical /
// estimated busyness is intentionally hidden — without live sensors it's
// guesswork. Hours stay as the reliable scaffolding.

struct GymView: View {
    let store: GymStore
    @Environment(\.openSettings) private var openSettings

    // NavigationStack + empty bar matches Eat's top chrome so all four tabs
    // share the same status-bar edge on iOS 26.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Gym", subtitle: "Beat the rush at the ARC", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.screen.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.bar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await store.load() }
            .task { await store.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.status {
        case .idle, .loading:
            VStack(spacing: 16) {
                SkeletonCard(height: 240)
                SkeletonCard(height: 120)
            }
        case .failed(let message):
            EmptyStateView(
                icon: "dumbbell",
                title: "Couldn't load the ARC",
                message: message,
                retry: { Task { await store.load() } }
            )
            .zotCard()
        case .loaded(let status):
            GymBusynessHero(status: status)
                .onAppear { PerfMetrics.markFirstContent("gym", cached: store.hydratedFromDisk) }
            // Rush curve is typical-pattern data — hide it unless we also have
            // a live reading (the curve then contextualizes the live %).
            if status.busyness?.source == .live,
               let curve = status.typicalCurve, curve.contains(where: { $0 > 0 }) {
                GymRushCard(curve: curve, status: status)
            }
            GymHoursCard(status: status)
            if status.hoursApproximate {
                GymApproximateHoursFootnote()
            }
        }
    }
}

// MARK: - Busyness hero

struct GymBusynessHero: View {
    let status: GymStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARC")
                        .font(ZotFont.cardTitle)
                    Text("Anteater Recreation Center")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(isOpen: status.openNow)
            }

            // Only show live Waitz occupancy — typical % is hidden as guesswork.
            if let point = status.busyness, point.source == .live, let percent = point.percent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(percent)%")
                            .font(.system(size: 44, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(point.level.color)
                        Text(point.level.label)
                            .font(ZotFont.sectionTitle)
                            .foregroundStyle(point.level.color)
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(percent) percent full, \(point.level.label)")

                    OccupancyBar(percent: percent, level: point.level)

                    HStack {
                        if let count = point.count {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(count) people")
                                    .font(ZotFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        UpdatedAgoText(date: point.updatedAt)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(.secondary)
                    Text(status.openNow ? "Live busyness unavailable right now" : "Closed — see you tomorrow")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Hours, demoted to one quiet line.
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(hoursLine)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private var hoursLine: String {
        guard let hours = status.todayHours else { return "Hours unavailable" }
        // "6:00 AM – 12:00 AM" -> "Open until 12:00 AM" while open.
        if status.openNow, let close = hours.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces) {
            return "Open until \(close)"
        }
        return "Today: \(hours)"
    }
}

// MARK: - Today's rush card

struct GymRushCard: View {
    let curve: [Int]
    let status: GymStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Today at the ARC")
                    .font(ZotFont.sectionTitle)
                TypicalTag()
                Spacer()
            }
            RushStrip(curve: curve, currentHour: UCITime.nowMinutes() / 60)
            if let busiest = status.busiestSummary {
                Text([busiest, status.quietestSummary].compactMap(\.self).joined(separator: " · "))
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }
}

// MARK: - Collapsible week hours

struct GymHoursCard: View {
    let status: GymStatus
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
                Haptics.selection()
            } label: {
                HStack {
                    Text("This week's hours")
                        .font(ZotFont.sectionTitle)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide this week's hours" : "Show this week's hours")

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(status.weekHours) { day in
                        let isToday = day.day == Self.todayName()
                        HStack {
                            Text(day.day)
                                .font(isToday ? ZotFont.body.weight(.semibold) : ZotFont.body)
                                .foregroundStyle(isToday ? Color.uciBlue : Color.primary)
                            Spacer()
                            Text(day.hours)
                                .font(isToday ? ZotFont.body.weight(.semibold) : ZotFont.body)
                                .foregroundStyle(isToday ? Color.uciBlue : Color.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            isToday ? Color.uciBlue.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            isToday ? "Today, \(day.day): \(day.hours)" : "\(day.day): \(day.hours)"
                        )
                    }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    /// Weekday name ("Sunday".."Saturday") in UCI's timezone, matching `DayHours.day`.
    static func todayName(for date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let pacific = TimeZone(identifier: "America/Los_Angeles") {
            calendar.timeZone = pacific
        }
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        return names[weekday - 1]
    }
}

// MARK: - Approximate-hours footnote

struct GymApproximateHoursFootnote: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hours from the maintained schedule — verify at campusrec.uci.edu")
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                Link(
                    "campusrec.uci.edu/arc/hours",
                    destination: URL(string: "https://www.campusrec.uci.edu/arc/hours.html")!
                )
                .font(ZotFont.caption.weight(.medium))
                .foregroundStyle(Color.uciBlue)
                .accessibilityLabel("Open ARC hours page at campusrec.uci.edu")
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Previews (fixture data only; no network)

#Preview("Typical estimate") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Gym", subtitle: "Beat the rush at the ARC")
            VStack(alignment: .leading, spacing: 16) {
                GymBusynessHero(
                    status: GymStatus(
                        name: "Anteater Recreation Center",
                        openNow: true,
                        todayHours: "6:00 AM – 12:00 AM",
                        weekHours: [],
                        busyness: BusynessPoint(
                            id: -100,
                            name: "ARC",
                            category: "Recreation",
                            count: nil,
                            capacity: nil,
                            percent: 75,
                            level: .busy,
                            isOpen: true,
                            hoursSummary: nil,
                            updatedAt: Date(),
                            subLocations: nil,
                            source: .typical
                        ),
                        hoursApproximate: true,
                        typicalCurve: nil,
                        busiestSummary: "Usually busiest 5 PM–8 PM",
                        quietestSummary: "usually quietest around 10 AM"
                    )
                )
                GymHoursCard(
                    status: GymStatus(
                        name: "ARC",
                        openNow: true,
                        todayHours: "6:00 AM – 12:00 AM",
                        weekHours: [
                            DayHours(day: "Sunday", hours: "8:00 AM – 12:00 AM"),
                            DayHours(day: "Monday", hours: "6:00 AM – 12:00 AM"),
                        ],
                        busyness: nil,
                        hoursApproximate: true
                    )
                )
                GymApproximateHoursFootnote()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    .background(Color.screen)
}
