import WidgetKit
import SwiftUI
import ActivityKit
import ZotEatsKit

// ZotEats home-screen widget: dining hall status at a glance — open state with
// closes-in/opens-at intelligence and typical occupancy — plus the quietest
// library on the medium size. Refreshes roughly every 20 minutes.

@main
struct ZotEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        DiningStatusWidget()
        TodaysMenuWidget()
        QuietestLibraryWidget()
        MealCountdownActivity()
    }
}

// MARK: - "Meal ends soon" Live Activity

private let activityBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
private let activityGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

struct MealCountdownActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealActivityAttributes.self) { context in
            // Lock screen banner.
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(activityGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.hallName)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(context.attributes.period) ends in")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
                Spacer()
                Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .foregroundStyle(activityGold)
            }
            .padding(16)
            .activityBackgroundTint(activityBlue)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(activityGold)
                        Text(context.attributes.hallName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84)
                        .foregroundStyle(activityGold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.period) is wrapping up — zot while you can")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(activityGold)
            } minimal: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
            }
        }
    }
}

// MARK: - Timeline

struct DiningStatusEntry: TimelineEntry {
    let date: Date
    let halls: [HallStatus]
    let quietest: (name: String, percent: Int)?

    struct HallStatus {
        let name: String
        let statusText: String
        let isOpen: Bool
        let occupancy: Int?
    }
}

struct DiningStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningStatusEntry {
        DiningStatusEntry(
            date: .now,
            halls: [
                .init(name: "The Anteatery", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 72),
                .init(name: "Brandywine", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 65),
            ],
            quietest: (name: "Science Library", percent: 12)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DiningStatusEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        // WidgetKit's completion closures aren't Sendable; box them to cross
        // into the async task under Swift 6 strict concurrency.
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiningStatusEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(20 * 60))))
        }
    }

    private func fetchEntry() async -> DiningStatusEntry {
        let locations = await DiningService().locations()
        let nowMinutes = UCITime.nowMinutes()

        let halls = locations.map { location -> DiningStatusEntry.HallStatus in
            let status: String
            switch location.openState(nowMinutes: nowMinutes) {
            case .open(let period, let closesAt):
                status = "\(period) · closes \(UCITime.format(minutes: closesAt % (24 * 60)))"
            case .openingLater(let period, let opensAt):
                status = "\(period) at \(UCITime.format(minutes: opensAt))"
            case .closedForToday:
                status = "Closed for today"
            case .unknown:
                status = location.todayHours ?? "Hours unavailable"
            }
            let estimate = TypicalBusyness.dining(periods: location.periods)
            return .init(
                name: location.name,
                statusText: status,
                isOpen: location.openNow,
                occupancy: FeatureFlags.diningHallOccupancy && location.openNow && estimate.percentNow > 0
                    ? estimate.percentNow : nil
            )
        }

        let quietest = (try? await BusynessService().all())?
            .filter { $0.isOpen && $0.percent != nil }
            .min { ($0.percent ?? 101) < ($1.percent ?? 101) }
            .map { (name: $0.name, percent: $0.percent ?? 0) }

        return DiningStatusEntry(date: .now, halls: halls, quietest: quietest)
    }
}

/// Carries a non-Sendable value across a concurrency boundary we know is safe
/// (WidgetKit invokes its completions in a thread-safe manner).
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Widget

struct DiningStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsDiningStatus", provider: DiningStatusProvider()) { entry in
            DiningStatusView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
        }
        .configurationDisplayName("Dining Halls")
        .description("Open status, hours, and how busy the halls usually are right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DiningStatusView: View {
    let entry: DiningStatusEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 9) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text("ZOTEATS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
            }
            .foregroundStyle(gold)

            ForEach(entry.halls.prefix(family == .systemSmall ? 2 : 3), id: \.name) { hall in
                hallRow(hall)
            }

            if family == .systemMedium, let quietest = entry.quietest {
                Divider()
                    .overlay(.white.opacity(0.25))
                HStack(spacing: 5) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(gold)
                    Text("Quietest: \(quietest.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text("\(quietest.percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(hall.isOpen ? Color.green : Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(shortName(hall.name))
                    .font(.system(size: family == .systemSmall ? 12 : 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 3)
                if let occupancy = hall.occupancy {
                    Text("\(occupancy)%")
                        .font(.system(size: family == .systemSmall ? 12 : 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }
            Text(hall.statusText)
                .font(.system(size: family == .systemSmall ? 10 : 11))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(hall.name), \(hall.statusText)\(hall.occupancy.map { ", \($0) percent occupancy" } ?? "")"
        )
    }

    /// "The Anteatery" -> "Anteatery" for tight widget rows.
    private func shortName(_ name: String) -> String {
        name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
    }
}

#Preview(as: .systemMedium) {
    DiningStatusWidget()
} timeline: {
    DiningStatusEntry(
        date: .now,
        halls: [
            .init(name: "The Anteatery", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 72),
            .init(name: "Brandywine", statusText: "Dinner at 4:30 PM", isOpen: false, occupancy: nil),
        ],
        quietest: (name: "Science Library", percent: 12)
    )
}

// MARK: - Today's Menu widget (medium)

struct TodaysMenuEntry: TimelineEntry {
    let date: Date
    let hallName: String
    let period: String
    let dishes: [String]
}

struct TodaysMenuProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysMenuEntry {
        TodaysMenuEntry(
            date: .now,
            hallName: "The Anteatery",
            period: "Lunch",
            dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni", "Farro Salad"]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysMenuEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysMenuEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
        }
    }

    private func fetchEntry() async -> TodaysMenuEntry {
        let service = DiningService()
        let locations = await service.locations()
        let nowMinutes = UCITime.nowMinutes()

        // Prefer an open hall; otherwise show the first one.
        guard let hall = locations.first(where: \.openNow) ?? locations.first else {
            return TodaysMenuEntry(date: .now, hallName: "UCI Dining", period: "", dishes: [])
        }

        // The meal being served now, else the next one today, else the last.
        let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        let period = timed.first { nowMinutes >= $0.startMinutes! && nowMinutes < $0.endMinutes! }?.name
            ?? timed.first { $0.startMinutes! > nowMinutes }?.name
            ?? hall.availablePeriods.last
            ?? ""

        var dishes: [String] = []
        if !period.isEmpty, let menu = try? await service.menu(for: hall.id, period: period) {
            var seen = Set<String>()
            dishes = menu.stations
                .flatMap(\.items)
                .map(\.name)
                .filter { seen.insert($0.lowercased()).inserted }
        }
        return TodaysMenuEntry(
            date: .now,
            hallName: hall.name,
            period: period,
            dishes: Array(dishes.prefix(4))
        )
    }
}

struct TodaysMenuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsTodaysMenu", provider: TodaysMenuProvider()) { entry in
            TodaysMenuView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
        }
        .configurationDisplayName("Today's Menu")
        .description("What's being served right now at the dining hall.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodaysMenuView: View {
    let entry: TodaysMenuEntry

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text(entry.hallName.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .lineLimit(1)
                Spacer()
                if !entry.period.isEmpty {
                    Text(entry.period)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(gold)

            if entry.dishes.isEmpty {
                Spacer()
                Text("No menu posted right now — check back at the next meal.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            } else {
                ForEach(entry.dishes, id: \.self) { dish in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gold)
                            .frame(width: 3.5, height: 3.5)
                        Text(dish)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.hallName) \(entry.period): \(entry.dishes.joined(separator: ", "))"
        )
    }
}

#Preview(as: .systemMedium) {
    TodaysMenuWidget()
} timeline: {
    TodaysMenuEntry(
        date: .now,
        hallName: "The Anteatery",
        period: "Lunch",
        dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni", "Farro Salad"]
    )
}

// MARK: - Quietest library (lock screen / StandBy)

struct QuietestLibraryEntry: TimelineEntry {
    let date: Date
    let name: String
    let percent: Int?
}

struct QuietestLibraryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuietestLibraryEntry {
        QuietestLibraryEntry(date: .now, name: "Science Library", percent: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuietestLibraryEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuietestLibraryEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }

    private func fetchEntry() async -> QuietestLibraryEntry {
        let quietest = (try? await BusynessService().all())?
            .filter { $0.isOpen && $0.percent != nil }
            .min { ($0.percent ?? 101) < ($1.percent ?? 101) }
        guard let quietest else {
            return QuietestLibraryEntry(date: .now, name: "Libraries closed", percent: nil)
        }
        return QuietestLibraryEntry(date: .now, name: quietest.name, percent: quietest.percent)
    }
}

struct QuietestLibraryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsQuietestLibrary", provider: QuietestLibraryProvider()) { entry in
            QuietestLibraryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Quietest Library")
        .description("The least busy library right now, on your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct QuietestLibraryView: View {
    let entry: QuietestLibraryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            if let percent = entry.percent {
                Gauge(value: Double(percent), in: 0...100) {
                    Image(systemName: "books.vertical.fill")
                } currentValueLabel: {
                    Text("\(percent)%")
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircular)
                .accessibilityLabel("\(entry.name), \(percent) percent full")
            } else {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .accessibilityLabel(entry.name)
            }
        default:
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(entry.percent.map { "\($0)% full · quietest now" } ?? "No live data")
                        .font(.system(size: 11))
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(entry.name)\(entry.percent.map { ", \($0) percent full, quietest library right now" } ?? "")"
            )
        }
    }
}

#Preview(as: .accessoryCircular) {
    QuietestLibraryWidget()
} timeline: {
    QuietestLibraryEntry(date: .now, name: "Science Library", percent: 12)
}
