import SwiftUI
import ZotEatsKit

// Gym screen — Anteater Recreation Center status: hero card with live
// occupancy, weekly hours, and a schedule-source footnote when applicable.

struct GymView: View {
    @State private var store = GymStore()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Gym", subtitle: "Anteater Recreation Center", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.screen)
            .refreshable { await store.load() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await store.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch store.status {
        case .idle, .loading:
            VStack(spacing: 16) {
                SkeletonCard(height: 220)
                SkeletonCard(height: 300)
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
            GymHeroCard(status: status)
            GymWeekHoursCard(weekHours: status.weekHours)
            if status.hoursApproximate {
                GymApproximateHoursFootnote()
            }
        }
    }
}

// MARK: - Hero card

struct GymHeroCard: View {
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

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(ZotFont.pill)
                    .foregroundStyle(.secondary)
                Text(status.todayHours ?? "Hours unavailable")
                    .font(ZotFont.pill)
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's hours: \(status.todayHours ?? "unavailable")")

            Divider()

            if let busyness = status.busyness {
                GymLiveOccupancySection(point: busyness)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .foregroundStyle(.secondary)
                    Text("Live crowd data isn't available for the ARC right now")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }
}

private struct GymLiveOccupancySection: View {
    let point: BusynessPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live occupancy")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let percent = point.percent {
                    Text("\(percent)%")
                        .font(.system(size: 46, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(point.level.color)
                } else {
                    Text("—")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Text(point.level.label)
                    .font(ZotFont.sectionTitle)
                    .foregroundStyle(point.level.color)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(occupancyAccessibilityLabel)

            OccupancyBar(percent: point.percent, level: point.level)

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
    }

    private var occupancyAccessibilityLabel: String {
        if let percent = point.percent {
            return "\(percent) percent full, \(point.level.label)"
        }
        return point.level.label
    }
}

// MARK: - Week hours card

struct GymWeekHoursCard: View {
    let weekHours: [DayHours]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Week")
                .font(ZotFont.sectionTitle)
                .padding(.bottom, 4)

            ForEach(weekHours) { day in
                let isToday = day.day == Self.todayName()
                HStack {
                    Text(day.day)
                        .font(isToday ? ZotFont.body.weight(.bold) : ZotFont.body)
                        .foregroundStyle(isToday ? Color.uciBlue : Color.primary)
                    Spacer()
                    Text(day.hours)
                        .font(isToday ? ZotFont.body.weight(.bold) : ZotFont.body)
                        .foregroundStyle(isToday ? Color.uciBlue : Color.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isToday ? Color.uciBlue.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    isToday ? "Today, \(day.day): \(day.hours)" : "\(day.day): \(day.hours)"
                )
            }
        }
        .padding(18)
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

#Preview("Loaded") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Gym", subtitle: "Anteater Recreation Center")
            VStack(alignment: .leading, spacing: 16) {
                GymHeroCard(
                    status: GymStatus(
                        name: "Anteater Recreation Center",
                        openNow: true,
                        todayHours: "6:00 AM – 11:00 PM",
                        weekHours: [
                            DayHours(day: "Sunday", hours: "8:00 AM – 11:00 PM"),
                            DayHours(day: "Monday", hours: "6:00 AM – 11:00 PM"),
                            DayHours(day: "Tuesday", hours: "6:00 AM – 11:00 PM"),
                            DayHours(day: "Wednesday", hours: "6:00 AM – 11:00 PM"),
                            DayHours(day: "Thursday", hours: "6:00 AM – 11:00 PM"),
                            DayHours(day: "Friday", hours: "6:00 AM – 10:00 PM"),
                            DayHours(day: "Saturday", hours: "8:00 AM – 10:00 PM"),
                        ],
                        busyness: BusynessPoint(
                            id: 1,
                            name: "ARC",
                            category: "Recreation",
                            count: 214,
                            capacity: 500,
                            percent: 43,
                            level: .busy,
                            isOpen: true,
                            hoursSummary: nil,
                            updatedAt: Date(),
                            subLocations: nil
                        ),
                        hoursApproximate: true
                    )
                )
                GymWeekHoursCard(weekHours: [
                    DayHours(day: "Sunday", hours: "8:00 AM – 11:00 PM"),
                    DayHours(day: "Monday", hours: "6:00 AM – 11:00 PM"),
                    DayHours(day: "Tuesday", hours: "6:00 AM – 11:00 PM"),
                    DayHours(day: "Wednesday", hours: "6:00 AM – 11:00 PM"),
                    DayHours(day: "Thursday", hours: "6:00 AM – 11:00 PM"),
                    DayHours(day: "Friday", hours: "6:00 AM – 10:00 PM"),
                    DayHours(day: "Saturday", hours: "8:00 AM – 10:00 PM"),
                ])
                GymApproximateHoursFootnote()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    .background(Color.screen)
}

#Preview("No live data") {
    ScrollView {
        GymHeroCard(
            status: GymStatus(
                name: "Anteater Recreation Center",
                openNow: false,
                todayHours: nil,
                weekHours: [],
                busyness: nil,
                hoursApproximate: false
            )
        )
        .padding(20)
    }
    .background(Color.screen)
}
