import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
import ZotEatsKit

// Home-screen + lock-screen widgets for ZotEats:
// dining status, today's menu (pick a hall), campus spots open now,
// ARC gym status, and quietest library (with floor when available).

@main
struct ZotEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Nested bundles stay under WidgetBundleBuilder's arity limit.
        HomeScreenWidgets()
        LockScreenWidgets()
    }
}

private struct HomeScreenWidgets: WidgetBundle {
    var body: some Widget {
        DiningStatusWidget()
        TodaysMenuWidget()
        CampusOpenWidget()
        ArcStatusWidget()
    }
}

private struct LockScreenWidgets: WidgetBundle {
    var body: some Widget {
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

// MARK: - Today's Menu widget (configurable hall · medium / large)

enum HallOption: String, AppEnum {
    case auto
    case anteatery
    case brandywine

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dining Hall"
    static var caseDisplayRepresentations: [HallOption: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: "Auto (open now)"),
        .anteatery: DisplayRepresentation(title: "The Anteatery"),
        .brandywine: DisplayRepresentation(title: "Brandywine"),
    ]

    var hallID: String? {
        switch self {
        case .auto: return nil
        case .anteatery: return "anteatery"
        case .brandywine: return "brandywine"
        }
    }
}

struct TodaysMenuConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Today's Menu"
    static var description: IntentDescription = IntentDescription(
        "Pick which dining hall's menu to show."
    )

    @Parameter(title: "Hall", default: .auto)
    var hall: HallOption
}

struct TodaysMenuEntry: TimelineEntry {
    let date: Date
    let hallName: String
    let period: String
    let dishes: [String]
}

struct TodaysMenuProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodaysMenuEntry {
        TodaysMenuEntry(
            date: .now,
            hallName: "The Anteatery",
            period: "Lunch",
            dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni", "Farro Salad", "Baked Potato"]
        )
    }

    func snapshot(for configuration: TodaysMenuConfigurationIntent, in context: Context) async -> TodaysMenuEntry {
        if context.isPreview { return placeholder(in: context) }
        return await fetchEntry(for: configuration)
    }

    func timeline(for configuration: TodaysMenuConfigurationIntent, in context: Context) async -> Timeline<TodaysMenuEntry> {
        let entry = await fetchEntry(for: configuration)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60)))
    }

    private func fetchEntry(for configuration: TodaysMenuConfigurationIntent) async -> TodaysMenuEntry {
        let service = DiningService()
        let locations = await service.locations()
        let nowMinutes = UCITime.nowMinutes()

        let hall: DiningLocation?
        if let id = configuration.hall.hallID {
            hall = locations.first { $0.id == id } ?? locations.first
        } else {
            hall = locations.first(where: \.openNow) ?? locations.first
        }
        guard let hall else {
            return TodaysMenuEntry(date: .now, hallName: "UCI Dining", period: "", dishes: [])
        }

        let pills = DiningService.primaryPeriods(from: hall.availablePeriods)
        let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        let liveName = timed.first { nowMinutes >= $0.startMinutes! && nowMinutes < $0.endMinutes! }?.name
            ?? timed.first { $0.startMinutes! > nowMinutes }?.name
            ?? hall.availablePeriods.last
            ?? ""
        let period: String = {
            let lower = liveName.lowercased()
            if lower.contains("brunch") || lower.contains("breakfast"), pills.contains("Breakfast") {
                return "Breakfast"
            }
            if lower.contains("lunch"), pills.contains("Lunch") { return "Lunch" }
            if lower.contains("dinner"), pills.contains("Dinner") { return "Dinner" }
            return pills.first ?? liveName
        }()

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
            dishes: dishes
        )
    }
}

struct TodaysMenuWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ZotEatsTodaysMenu",
            intent: TodaysMenuConfigurationIntent.self,
            provider: TodaysMenuProvider()
        ) { entry in
            TodaysMenuView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
        }
        .configurationDisplayName("Today's Menu")
        .description("What's being served — pick Anteatery or Brandywine, or auto.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TodaysMenuView: View {
    let entry: TodaysMenuEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    private var dishLimit: Int { family == .systemLarge ? 10 : 4 }

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

            let dishes = Array(entry.dishes.prefix(dishLimit))
            if dishes.isEmpty {
                Spacer()
                Text("No menu posted right now — check back at the next meal.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            } else {
                ForEach(dishes, id: \.self) { dish in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gold)
                            .frame(width: 3.5, height: 3.5)
                        Text(dish)
                            .font(.system(size: family == .systemLarge ? 13 : 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                if entry.dishes.count > dishLimit {
                    Text("+\(entry.dishes.count - dishLimit) more")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.hallName) \(entry.period): \(Array(entry.dishes.prefix(dishLimit)).joined(separator: ", "))"
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

// MARK: - Campus open now

struct CampusOpenEntry: TimelineEntry {
    let date: Date
    let openPlaces: [(name: String, hours: String)]
    let totalOpen: Int
}

struct CampusOpenProvider: TimelineProvider {
    func placeholder(in context: Context) -> CampusOpenEntry {
        CampusOpenEntry(
            date: .now,
            openPlaces: [
                (name: "Starbucks @ Student Center", hours: "until 8 PM"),
                (name: "Zot N Go", hours: "Open 24 hours"),
                (name: "Panda Express", hours: "until 7 PM"),
            ],
            totalOpen: 6
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CampusOpenEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CampusOpenEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(20 * 60))))
        }
    }

    private func fetchEntry() async -> CampusOpenEntry {
        let places = (try? await CampusService().places()) ?? []
        let open = places
            .filter(\.openNow)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let rows = open.prefix(4).map { place -> (String, String) in
            let hours = place.todayHours.map { compactHours($0) } ?? "Open"
            return (place.name, hours)
        }
        return CampusOpenEntry(date: .now, openPlaces: rows.map { (name: $0.0, hours: $0.1) }, totalOpen: open.count)
    }

    /// "10:00 AM – 8:00 PM" -> "until 8:00 PM" for tight rows.
    private func compactHours(_ hours: String) -> String {
        if hours.localizedCaseInsensitiveContains("24") { return "Open 24 hours" }
        if let close = hours.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces), !close.isEmpty {
            return "until \(close)"
        }
        return hours
    }
}

struct CampusOpenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsCampusOpen", provider: CampusOpenProvider()) { entry in
            CampusOpenView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
        }
        .configurationDisplayName("Campus Open Now")
        .description("Which cafés and food courts are open right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CampusOpenView: View {
    let entry: CampusOpenEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("CAMPUS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
                Text("\(entry.totalOpen) open")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.16), in: Capsule())
                    .foregroundStyle(.white)
            }
            .foregroundStyle(gold)

            if entry.openPlaces.isEmpty {
                Spacer()
                Text("Nothing's open right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            } else if family == .systemSmall {
                Text(entry.openPlaces.first?.name ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let hours = entry.openPlaces.first?.hours {
                    Text(hours)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                if entry.totalOpen > 1 {
                    Text("+\(entry.totalOpen - 1) more open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(gold)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.openPlaces.prefix(3).enumerated()), id: \.offset) { _, place in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text(place.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(place.hours)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                if entry.totalOpen > 3 {
                    Text("+\(entry.totalOpen - 3) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(gold)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.totalOpen) campus spots open")
    }
}

#Preview(as: .systemMedium) {
    CampusOpenWidget()
} timeline: {
    CampusOpenEntry(
        date: .now,
        openPlaces: [
            (name: "Starbucks @ Student Center", hours: "until 8 PM"),
            (name: "Zot N Go", hours: "Open 24 hours"),
        ],
        totalOpen: 5
    )
}

// MARK: - ARC gym status

struct ArcStatusEntry: TimelineEntry {
    let date: Date
    let isOpen: Bool
    let hoursLine: String
    let livePercent: Int?
}

struct ArcStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcStatusEntry {
        ArcStatusEntry(date: .now, isOpen: true, hoursLine: "Open until 12 AM", livePercent: 42)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArcStatusEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArcStatusEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }

    private func fetchEntry() async -> ArcStatusEntry {
        let status = await GymService().status()
        let hoursLine: String = {
            guard let hours = status.todayHours else { return status.openNow ? "Open" : "Closed" }
            if status.openNow, let close = hours.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces) {
                return "Open until \(close)"
            }
            return status.openNow ? "Open · \(hours)" : "Closed · \(hours)"
        }()
        let livePercent = status.busyness.flatMap { point in
            point.source == .live ? point.percent : nil
        }
        return ArcStatusEntry(
            date: .now,
            isOpen: status.openNow,
            hoursLine: hoursLine,
            livePercent: livePercent
        )
    }
}

struct ArcStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsArcStatus", provider: ArcStatusProvider()) { entry in
            ArcStatusView(entry: entry)
        }
        .configurationDisplayName("ARC Gym")
        .description("Is the ARC open — and how full is it (live sensors only).")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct ArcStatusView: View {
    let entry: ArcStatusEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    private let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                if let percent = entry.livePercent {
                    Gauge(value: Double(percent), in: 0...100) {
                        Text("ARC")
                    } currentValueLabel: {
                        Text("\(percent)%")
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                    }
                    .gaugeStyle(.accessoryCircular)
                    .accessibilityLabel("ARC \(percent) percent full")
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(entry.isOpen ? "Open" : "Closed")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .accessibilityLabel(entry.isOpen ? "ARC open" : "ARC closed")
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ARC")
                            .font(.system(size: 13, weight: .semibold))
                        Text(entry.livePercent.map { "\($0)% full · \(entry.hoursLine)" } ?? entry.hoursLine)
                            .font(.system(size: 11))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel("ARC, \(entry.hoursLine)")
            default:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("ARC")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                        Spacer()
                        Circle()
                            .fill(entry.isOpen ? Color.green : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                    }
                    .foregroundStyle(gold)

                    if let percent = entry.livePercent {
                        Text("\(percent)%")
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("full · live")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text(entry.isOpen ? "Open" : "Closed")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(entry.hoursLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .accessibilityLabel("ARC, \(entry.hoursLine)\(entry.livePercent.map { ", \($0) percent full" } ?? "")")
            }
        }
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular:
                Color.clear
            default:
                uciBlue
            }
        }
    }
}

#Preview(as: .systemSmall) {
    ArcStatusWidget()
} timeline: {
    ArcStatusEntry(date: .now, isOpen: true, hoursLine: "Open until 12:00 AM", livePercent: 38)
}

// MARK: - Quietest library (home + lock screen)

struct QuietestLibraryEntry: TimelineEntry {
    let date: Date
    let name: String
    let percent: Int?
}

struct QuietestLibraryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuietestLibraryEntry {
        QuietestLibraryEntry(date: .now, name: "Langson · 4th Floor", percent: 8)
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
        let facilities = (try? await BusynessService().all()) ?? []
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries

        var floorCandidates: [(title: String, percent: Int)] = []
        for facility in pool where facility.isOpen {
            for floor in facility.subLocations ?? [] {
                guard floor.isOpen, let percent = floor.percent else { continue }
                floorCandidates.append((title: "\(shortLibrary(facility.name)) · \(floor.name)", percent: percent))
            }
        }
        if let best = floorCandidates.min(by: { $0.percent < $1.percent }) {
            return QuietestLibraryEntry(date: .now, name: best.title, percent: best.percent)
        }
        if let quietest = pool
            .filter { $0.isOpen && $0.percent != nil }
            .min(by: { ($0.percent ?? 101) < ($1.percent ?? 101) }) {
            return QuietestLibraryEntry(date: .now, name: quietest.name, percent: quietest.percent)
        }
        return QuietestLibraryEntry(date: .now, name: "Libraries closed", percent: nil)
    }

    private func shortLibrary(_ name: String) -> String {
        name
            .replacingOccurrences(of: " Library", with: "")
            .replacingOccurrences(of: "Science", with: "Sci Lib")
    }
}

struct QuietestLibraryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsQuietestLibrary", provider: QuietestLibraryProvider()) { entry in
            QuietestLibraryView(entry: entry)
        }
        .configurationDisplayName("Quietest Library")
        .description("The quietest library floor right now — home screen or lock screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuietestLibraryView: View {
    let entry: QuietestLibraryEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    private let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)

    var body: some View {
        Group {
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
            case .accessoryRectangular:
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
            default:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("STUDY")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                        Spacer()
                    }
                    .foregroundStyle(gold)

                    Text(entry.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    if let percent = entry.percent {
                        Text("\(percent)% full")
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(gold)
                        Text("quietest right now")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text("No live data")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel(
                    "\(entry.name)\(entry.percent.map { ", \($0) percent full" } ?? "")"
                )
            }
        }
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular, .accessoryRectangular:
                Color.clear
            default:
                uciBlue
            }
        }
    }
}

#Preview(as: .accessoryCircular) {
    QuietestLibraryWidget()
} timeline: {
    QuietestLibraryEntry(date: .now, name: "Langson · 4th Floor", percent: 8)
}
