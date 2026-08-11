import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
import ZotEatsKit

// Home-screen + lock-screen widgets for Anteats:
// dining status, today's menu (pick a hall), campus spots open now,
// ARC gym status, and quietest library (with floor when available).

@main
struct ZotEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Keep flat — nested WidgetBundles no longer type-check as Widget
        // expressions on current SDKs (WidgetBundleBuilder arity is fine at 6).
        DiningStatusWidget()
        TodaysMenuWidget()
        CampusOpenWidget()
        ArcStatusWidget()
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
            .widgetURL(
                AnteatsDeepLink.eat(
                    hall: context.attributes.hallID,
                    period: context.attributes.period
                ).url
            )
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
                    Text("\(context.attributes.period) is wrapping up — grab a bite while you can")
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
            .widgetURL(
                AnteatsDeepLink.eat(
                    hall: context.attributes.hallID,
                    period: context.attributes.period
                ).url
            )
        }
    }
}

// MARK: - Timeline

struct DiningStatusEntry: TimelineEntry {
    let date: Date
    let halls: [HallStatus]
    /// Medium tip — open quietest floor or overnight "Libraries closed".
    let quietest: QuietestLibraryGlance.DiningStatusTip?

    struct HallStatus {
        /// Anteater API hall id for deep links.
        let id: String
        let name: String
        let statusText: String
        let isOpen: Bool
        let occupancy: Int?
        /// When set, widget shows a live countdown (closes / opens).
        let countdownEnd: Date?
        let countdownKind: CountdownKind?
        /// Primary meal pill for Eat deep links (nil after hours / unknown).
        let deepLinkPeriod: String?

        enum CountdownKind {
            case closes
            case opens
        }

        init(
            id: String,
            name: String,
            statusText: String,
            isOpen: Bool,
            occupancy: Int?,
            countdownEnd: Date?,
            countdownKind: CountdownKind?,
            deepLinkPeriod: String? = nil
        ) {
            self.id = id
            self.name = name
            self.statusText = statusText
            self.isOpen = isOpen
            self.occupancy = occupancy
            self.countdownEnd = countdownEnd
            self.countdownKind = countdownKind
            self.deepLinkPeriod = deepLinkPeriod
        }
    }
}

struct DiningStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningStatusEntry {
        DiningStatusEntry(
            date: .now,
            halls: [
                .init(id: "anteatery", name: "The Anteatery", statusText: "Dinner", isOpen: true, occupancy: 72, countdownEnd: .now.addingTimeInterval(3600), countdownKind: .closes),
                .init(id: "brandywine", name: "Brandywine", statusText: "Dinner", isOpen: true, occupancy: 65, countdownEnd: .now.addingTimeInterval(5400), countdownKind: .closes),
                .init(id: "mesa-commons", name: "Mesa Commons", statusText: "Dinner", isOpen: true, occupancy: 40, countdownEnd: .now.addingTimeInterval(4800), countdownKind: .closes),
            ],
            quietest: .open(name: "Science Library", percent: 12, facilityID: 2)
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
            var boundaries = entry.halls.compactMap(\.countdownEnd)
            boundaries.append(UCITime.nextIrvineMidnight())
            let reload = WidgetRefreshMath.nextReload(
                now: .now,
                boundaries: boundaries,
                maxInterval: 20 * 60
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> DiningStatusEntry {
        let locations = await DiningService().locations()
        let nowMinutes = UCITime.nowMinutes()

        let halls = locations.map { location -> DiningStatusEntry.HallStatus in
            let status: String
            var countdownEnd: Date?
            var countdownKind: DiningStatusEntry.HallStatus.CountdownKind?
            let state = location.openState(nowMinutes: nowMinutes)
            switch state {
            case .open(let period, let closesAt):
                status = period
                countdownEnd = UCITime.date(forMinutes: closesAt, nowMinutes: nowMinutes)
                countdownKind = .closes
            case .openingLater(let period, let opensAt):
                status = period
                countdownEnd = UCITime.date(forMinutes: opensAt, nowMinutes: nowMinutes)
                countdownKind = .opens
            case .closedForToday:
                if let open = location.opensTomorrowAtMinutes {
                    status = location.opensTomorrowPeriod ?? "Opens tomorrow"
                    countdownEnd = UCITime.date(forMinutes: open, nowMinutes: nowMinutes)
                    countdownKind = .opens
                } else {
                    status = "Closed for today"
                }
            case .unknown:
                status = location.todayHours ?? "Hours unavailable"
            }
            let estimate = TypicalBusyness.dining(periods: location.periods)
            return .init(
                id: location.id,
                name: location.name,
                statusText: status,
                isOpen: location.openNow,
                occupancy: FeatureFlags.diningHallOccupancy && location.openNow && estimate.percentNow > 0
                    ? estimate.percentNow : nil,
                countdownEnd: countdownEnd,
                countdownKind: countdownKind,
                deepLinkPeriod: DiningStatusDeepLink.period(
                    for: state,
                    availablePeriods: location.availablePeriods
                )
            )
        }

        let quietest: QuietestLibraryGlance.DiningStatusTip?
        if let places = try? await BusynessService().all() {
            quietest = QuietestLibraryGlance.diningStatusTip(from: places)
        } else {
            quietest = nil
        }

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
                .widgetURL(AnteatsWidgetURL.eat)
        }
        .configurationDisplayName("Dining Halls")
        .description("Open status and when halls open or close.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Deep links into the app when a widget is tapped.
private enum AnteatsWidgetURL {
    static let eat = AnteatsDeepLink.eat().url
    static let campus = AnteatsDeepLink.campus(placeID: nil).url
    static let gym = AnteatsDeepLink.gym().url
    static let study = AnteatsDeepLink.study().url
}

struct DiningStatusView: View {
    let entry: DiningStatusEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    private var isCompact: Bool { family == .systemSmall }
    private var visibleHalls: ArraySlice<DiningStatusEntry.HallStatus> {
        entry.halls.prefix(DiningStatusLayout.hallLimit(isCompact: isCompact))
    }
    private var hallCount: Int { visibleHalls.count }

    var body: some View {
        VStack(alignment: .leading, spacing: DiningStatusLayout.rowSpacing(isCompact: isCompact, hallCount: hallCount)) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text("ANTEATS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
            }
            .foregroundStyle(gold)

            ForEach(Array(visibleHalls), id: \.id) { hall in
                Link(destination: AnteatsDeepLink.eat(hall: hall.id, period: hall.deepLinkPeriod).url) {
                    hallRow(hall)
                }
            }

            if family == .systemMedium, let tip = entry.quietest {
                Divider()
                    .overlay(.white.opacity(0.25))
                switch tip {
                case .open(let name, let percent, let facilityID):
                    Link(destination: AnteatsDeepLink.study(facilityID: facilityID).url) {
                        HStack(spacing: 5) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(gold)
                            Text("Quietest: \(name)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer()
                            Text("\(percent)%")
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                        }
                    }
                case .librariesClosed:
                    Link(destination: AnteatsDeepLink.study().url) {
                        HStack(spacing: 5) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(gold.opacity(0.85))
                            Text(QuietestLibraryGlance.closedTitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        let nameSize = DiningStatusLayout.nameFontSize(isCompact: isCompact, hallCount: hallCount)
        let statusSize = DiningStatusLayout.statusFontSize(isCompact: isCompact, hallCount: hallCount)
        return VStack(alignment: .leading, spacing: DiningStatusLayout.usesDenseRows(hallCount: hallCount) ? 0 : 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(hall.isOpen ? Color.green : Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(shortName(hall.name))
                    .font(.system(size: nameSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 3)
                if let occupancy = hall.occupancy {
                    Text("\(occupancy)%")
                        .font(.system(size: nameSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }
            HStack(spacing: 4) {
                Text(hall.statusText)
                    .font(.system(size: statusSize))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                if let end = hall.countdownEnd, let kind = hall.countdownKind, end > Date() {
                    Text(kind == .closes ? "· closes" : "· opens")
                        .font(.system(size: statusSize))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .font(.system(size: statusSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                        .multilineTextAlignment(.leading)
                }
            }
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
            .init(id: "anteatery", name: "The Anteatery", statusText: "Dinner", isOpen: true, occupancy: 72, countdownEnd: .now.addingTimeInterval(3600), countdownKind: .closes),
            .init(id: "brandywine", name: "Brandywine", statusText: "Dinner", isOpen: false, occupancy: nil, countdownEnd: .now.addingTimeInterval(7200), countdownKind: .opens),
            .init(id: "mesa-commons", name: "Mesa Commons", statusText: "Dinner", isOpen: true, occupancy: 40, countdownEnd: .now.addingTimeInterval(4800), countdownKind: .closes),
        ],
        quietest: .open(name: "Science Library", percent: 12, facilityID: 2)
    )
}

// MARK: - Today's Menu widget (configurable hall · medium / large)

/// Dynamic hall picker — Auto + whatever `/restaurants` returns (third commons
/// appears without shipping a new AppEnum case).
struct DiningHallEntity: AppEntity, Equatable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dining Hall")
    static var defaultQuery = DiningHallEntityQuery()

    /// `"auto"` or a live Anteater API hall id (`anteatery`, `brandywine`, …).
    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    /// Nil when Auto — provider picks an open hall.
    var hallID: String? {
        id == TodaysMenuHallChoices.autoID ? nil : id
    }

    static var auto: DiningHallEntity {
        DiningHallEntity(id: TodaysMenuHallChoices.autoID, title: TodaysMenuHallChoices.autoTitle)
    }
}

struct DiningHallEntityQuery: EntityQuery {
    func entities(for identifiers: [DiningHallEntity.ID]) async throws -> [DiningHallEntity] {
        let all = await Self.allEntities()
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            if let known = byID[id] { return known }
            if id == TodaysMenuHallChoices.autoID { return .auto }
            return DiningHallEntity(id: id, title: HallDirectory.displayName(for: id))
        }
    }

    func suggestedEntities() async throws -> [DiningHallEntity] {
        await Self.allEntities()
    }

    func defaultResult() async -> DiningHallEntity? {
        .auto
    }

    private static func allEntities() async -> [DiningHallEntity] {
        let locations = await DiningService().locations()
        return TodaysMenuHallChoices.options(from: locations).map {
            DiningHallEntity(id: $0.id, title: $0.title)
        }
    }
}

struct TodaysMenuConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Today's Menu"
    static let description: IntentDescription = IntentDescription(
        "Pick which dining hall's menu to show — including any new commons as they open."
    )

    @Parameter(title: "Hall", default: DiningHallEntity.auto)
    var hall: DiningHallEntity
}

struct TodaysMenuEntry: TimelineEntry {
    let date: Date
    let hallName: String
    /// Anteater API id for deep links (`anteatery`, …).
    let hallID: String?
    let period: String
    let dishes: [String]
    /// Dish names that are favorited (subset of `dishes`), for heart markers.
    let favorited: Set<String>
    let periodEndsAt: Date?
    /// Extra WidgetKit reload points (meal start when still closed, etc.).
    let reloadBoundaries: [Date]
    /// Menu had dishes but Eat Filters removed every one.
    let filtersEmptiedMenu: Bool

    init(
        date: Date,
        hallName: String,
        hallID: String? = nil,
        period: String,
        dishes: [String],
        favorited: Set<String>,
        periodEndsAt: Date?,
        reloadBoundaries: [Date] = [],
        filtersEmptiedMenu: Bool = false
    ) {
        self.date = date
        self.hallName = hallName
        self.hallID = hallID
        self.period = period
        self.dishes = dishes
        self.favorited = favorited
        self.periodEndsAt = periodEndsAt
        self.reloadBoundaries = reloadBoundaries
        self.filtersEmptiedMenu = filtersEmptiedMenu
    }

    /// Opens Eat on the hall + meal this glance is showing.
    var deepLinkURL: URL {
        AnteatsDeepLink.eat(
            hall: hallID,
            period: period.isEmpty ? nil : period
        ).url
    }
}

struct TodaysMenuProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodaysMenuEntry {
        TodaysMenuEntry(
            date: .now,
            hallName: "The Anteatery",
            hallID: "anteatery",
            period: "Lunch",
            dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni", "Farro Salad", "Baked Potato"],
            favorited: ["Crispy Okra"],
            periodEndsAt: .now.addingTimeInterval(45 * 60)
        )
    }

    func snapshot(for configuration: TodaysMenuConfigurationIntent, in context: Context) async -> TodaysMenuEntry {
        if context.isPreview { return placeholder(in: context) }
        return await fetchEntry(for: configuration)
    }

    func timeline(for configuration: TodaysMenuConfigurationIntent, in context: Context) async -> Timeline<TodaysMenuEntry> {
        let entry = await fetchEntry(for: configuration)
        var boundaries = entry.reloadBoundaries
        if let end = entry.periodEndsAt { boundaries.append(end) }
        let reload = WidgetRefreshMath.nextReload(
            now: .now,
            boundaries: boundaries,
            maxInterval: 30 * 60
        )
        return Timeline(entries: [entry], policy: .after(reload))
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
            return TodaysMenuEntry(date: .now, hallName: "UCI Dining", period: "", dishes: [], favorited: [], periodEndsAt: nil)
        }

        let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timed,
            availablePeriods: hall.availablePeriods,
            nowMinutes: nowMinutes
        )
        let period = choice.period

        var dishes: [String] = []
        var favorited: Set<String> = []
        var filtersEmptiedMenu = false
        if !period.isEmpty, let menu = try? await service.menu(for: hall.id, period: period) {
            let built = SharedDefaults.todaysMenuDishes(
                stations: menu.stations,
                dietFilters: Set(SharedDefaults.dietFilters()),
                allergenAvoids: Set(SharedDefaults.allergenAvoids()),
                favorites: SharedDefaults.favoriteDishNames()
            )
            dishes = built.ordered
            favorited = built.favorited
            filtersEmptiedMenu = built.filtersEmptiedMenu
        }

        let periodEndsAt: Date? = choice.endsAtMinutes.map {
            UCITime.date(forMinutes: $0, nowMinutes: nowMinutes)
        }

        // Reload at next meal start and Irvine midnight (no overnight stale Dinner).
        var reloadBoundaries: [Date] = [UCITime.nextIrvineMidnight()]
        if let start = choice.upcomingStartMinutes {
            reloadBoundaries.append(UCITime.date(forMinutes: start, nowMinutes: nowMinutes))
        }

        return TodaysMenuEntry(
            date: .now,
            hallName: hall.name,
            hallID: hall.id,
            period: period,
            dishes: dishes,
            favorited: favorited,
            periodEndsAt: periodEndsAt,
            reloadBoundaries: reloadBoundaries,
            filtersEmptiedMenu: filtersEmptiedMenu
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
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("Today's Menu")
        .description("What's being served — Eat Filters + favorites from the app. Pick a hall or auto.")
        // system* for Home Screen; accessoryRectangular for Lock Screen / StandBy glance.
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

/// Clears App Group Eat Filters from the Home Screen when Today’s Menu is wiped empty.
struct ClearEatFiltersIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Eat Filters"
    static var description = IntentDescription(
        "Clear dietary and allergen filters so Today's Menu shows the full board."
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedDefaults.clearMenuFilters()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.todaysMenu)
        return .result(dialog: "Eat Filters cleared")
    }
}

struct TodaysMenuView: View {
    let entry: TodaysMenuEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    private var dishLimit: Int {
        switch family {
        case .systemLarge: return 10
        case .accessoryRectangular: return 2
        default: return 4
        }
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lunchGlance
        default:
            homeScreenMenu
        }
    }

    /// Compact Lock Screen / StandBy “what’s for lunch” glance.
    private var lunchGlance: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 11, weight: .semibold))
                Text(glanceTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if let first = Array(entry.dishes.prefix(dishLimit)).first {
                Text(first)
                    .font(.system(size: 12))
                    .opacity(0.85)
                    .lineLimit(1)
                if entry.dishes.count > 1 {
                    let second = entry.dishes[1]
                    Text(second)
                        .font(.system(size: 12))
                        .opacity(0.7)
                        .lineLimit(1)
                }
            } else {
                Text(entry.filtersEmptiedMenu
                     ? "Nothing matches Eat Filters"
                     : entry.period.isEmpty ? "See you at breakfast" : "Menu not posted yet")
                    .font(.system(size: 12))
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.hallName) \(entry.period): \(Array(entry.dishes.prefix(dishLimit)).joined(separator: ", "))"
        )
    }

    private var glanceTitle: String {
        let period = entry.period.isEmpty ? "Menu" : entry.period
        let hall = entry.hallName
            .replacingOccurrences(of: "The ", with: "")
        return "\(period) · \(hall)"
    }

    private var homeScreenMenu: some View {
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
                    HStack(spacing: 5) {
                        Text(entry.period)
                            .font(.system(size: 10, weight: .bold))
                        if let end = entry.periodEndsAt, end > Date() {
                            Text(timerInterval: Date.now...end, countsDown: true)
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                        }
                    }
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
                if entry.filtersEmptiedMenu {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nothing matches your Eat Filters.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                        Button(intent: ClearEatFiltersIntent()) {
                            Text("Clear filters")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(gold.opacity(0.95), in: Capsule())
                                .foregroundStyle(Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(
                        entry.period.isEmpty
                            ? "Dinner's done — breakfast posts overnight."
                            : "No menu posted right now — check back at the next meal."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            } else {
                ForEach(dishes, id: \.self) { dish in
                    HStack(spacing: 6) {
                        if entry.favorited.contains(dish) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(gold)
                        } else {
                            Circle()
                                .fill(gold)
                                .frame(width: 3.5, height: 3.5)
                        }
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
        hallID: "anteatery",
        period: "Lunch",
        dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni", "Farro Salad"],
        favorited: ["Crispy Okra"],
        periodEndsAt: .now.addingTimeInterval(45 * 60)
    )
}

#Preview(as: .accessoryRectangular) {
    TodaysMenuWidget()
} timeline: {
    TodaysMenuEntry(
        date: .now,
        hallName: "The Anteatery",
        hallID: "anteatery",
        period: "Lunch",
        dishes: ["Crispy Okra", "Grilled BBQ Pork Chops", "Elbow Macaroni"],
        favorited: ["Crispy Okra"],
        periodEndsAt: .now.addingTimeInterval(45 * 60)
    )
}

// MARK: - Campus open now

struct CampusOpenEntry: TimelineEntry {
    let date: Date
    let openPlaces: [(id: String, name: String, hours: String)]
    let totalOpen: Int
    /// When nothing is open — soonest reopen for empty-state copy / deep link.
    let nextOpen: CampusNextOpenHint.Hint?

    init(
        date: Date,
        openPlaces: [(id: String, name: String, hours: String)],
        totalOpen: Int,
        nextOpen: CampusNextOpenHint.Hint? = nil
    ) {
        self.date = date
        self.openPlaces = openPlaces
        self.totalOpen = totalOpen
        self.nextOpen = nextOpen
    }
}

struct CampusOpenProvider: TimelineProvider {
    func placeholder(in context: Context) -> CampusOpenEntry {
        CampusOpenEntry(
            date: .now,
            openPlaces: [
                (id: "starbucks-at-student-center", name: "Starbucks @ Student Center", hours: "until 8 PM"),
                (id: "zot-n-go", name: "Zot N Go", hours: "Open 24 hours"),
                (id: "panda-express", name: "Panda Express", hours: "until 7 PM"),
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
            let places = (try? await CampusService().places()) ?? []
            let entry = entry(from: places)
            let reload = CampusOpenReload.nextReload(now: .now, places: places)
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> CampusOpenEntry {
        let places = (try? await CampusService().places()) ?? []
        return entry(from: places)
    }

    private func entry(from places: [CampusPlace]) -> CampusOpenEntry {
        let open = places
            .filter(\.openNow)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let rows = open.prefix(4).map { place -> (id: String, name: String, hours: String) in
            let hours = CampusPlaceHoursLine.widgetOpenHours(
                todayHours: place.todayHours,
                closesAtMinutes: place.closesAtMinutes
            )
            return (id: place.id, name: place.name, hours: hours)
        }
        let nextOpen = open.isEmpty ? CampusNextOpenHint.best(from: places) : nil
        return CampusOpenEntry(
            date: .now,
            openPlaces: rows,
            totalOpen: open.count,
            nextOpen: nextOpen
        )
    }

}

struct CampusOpenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsCampusOpen", provider: CampusOpenProvider()) { entry in
            CampusOpenView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
                .widgetURL(AnteatsWidgetURL.campus)
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
                if let hint = entry.nextOpen {
                    Link(destination: AnteatsDeepLink.campus(placeID: hint.placeID).url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nothing's open right now.")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(hint.line)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(gold)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text("Nothing's open right now.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            } else if family == .systemSmall {
                if let first = entry.openPlaces.first {
                    Link(destination: AnteatsDeepLink.campus(placeID: first.id).url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(first.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Text(first.hours)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                if entry.totalOpen > 1 {
                    Text("+\(entry.totalOpen - 1) more open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(gold)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.openPlaces.prefix(3)), id: \.id) { place in
                    Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
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
            (id: "starbucks-at-student-center", name: "Starbucks @ Student Center", hours: "until 8 PM"),
            (id: "zot-n-go", name: "Zot N Go", hours: "Open 24 hours"),
        ],
        totalOpen: 5
    )
}

// MARK: - ARC gym status

struct ArcStatusEntry: TimelineEntry {
    let date: Date
    let isOpen: Bool
    let hoursLine: String
    /// Live Waitz % or typical-pattern estimate (see `isTypical`).
    let percent: Int?
    let isTypical: Bool

    init(
        date: Date,
        isOpen: Bool,
        hoursLine: String,
        percent: Int?,
        isTypical: Bool = false
    ) {
        self.date = date
        self.isOpen = isOpen
        self.hoursLine = hoursLine
        self.percent = percent
        self.isTypical = isTypical
    }
}

struct ArcStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcStatusEntry {
        ArcStatusEntry(date: .now, isOpen: true, hoursLine: "Open until 12 AM", percent: 42)
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
            let now = Date()
            let boundary = GymService.nextScheduleBoundary(now: now)
            let reload = WidgetRefreshMath.nextReload(
                now: now,
                boundaries: boundary.map { [$0] } ?? [],
                maxInterval: 15 * 60
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> ArcStatusEntry {
        let status = await GymService().status()
        let nowMinutes = UCITime.nowMinutes()
        let weekday = PacificTime.weekdayName()
        let hoursLine = ArcIdleCopy.hoursLine(
            openNow: status.openNow,
            todayHours: status.todayHours,
            nowMinutes: nowMinutes,
            opensAtMinutesToday: ArcIdleCopy.todayOpenMinutes(weekday: weekday),
            closesAtMinutesToday: ArcIdleCopy.todayCloseMinutes(weekday: weekday),
            opensAtMinutesTomorrow: ArcIdleCopy.tomorrowOpenMinutes(weekday: weekday)
        )
        let crowding = ArcWidgetGlance.crowding(from: status)
        return ArcStatusEntry(
            date: .now,
            isOpen: status.openNow,
            hoursLine: hoursLine,
            percent: crowding?.percent,
            isTypical: crowding?.isTypical ?? false
        )
    }
}

struct ArcStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsArcStatus", provider: ArcStatusProvider()) { entry in
            ArcStatusView(entry: entry)
                .widgetURL(AnteatsWidgetURL.gym)
        }
        .configurationDisplayName("ARC Gym")
        .description("Is the ARC open — and how full is it (live sensors, or typical when Waitz is quiet).")
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
                if let percent = entry.percent {
                    Gauge(value: Double(percent), in: 0...100) {
                        Text("ARC")
                    } currentValueLabel: {
                        Text("\(percent)%")
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                    }
                    .gaugeStyle(.accessoryCircular)
                    .accessibilityLabel(crowdingAccessibility(percent: percent))
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
                        Text(rectangularDetail)
                            .font(.system(size: 11))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel(
                    entry.percent.map { crowdingAccessibility(percent: $0) + ", \(entry.hoursLine)" }
                        ?? "ARC, \(entry.hoursLine)"
                )
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

                    if let percent = entry.percent {
                        Text("\(percent)%")
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("full · \(entry.isTypical ? "typical" : "live")")
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
                .accessibilityLabel(
                    "ARC, \(entry.hoursLine)"
                        + (entry.percent.map { ", \($0) percent full\(entry.isTypical ? ", typical estimate" : "")" } ?? "")
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

    private var rectangularDetail: String {
        guard let percent = entry.percent else { return entry.hoursLine }
        let source = entry.isTypical ? "typical" : "live"
        return "\(percent)% · \(source) · \(entry.hoursLine)"
    }

    private func crowdingAccessibility(percent: Int) -> String {
        "ARC \(percent) percent full\(entry.isTypical ? ", typical estimate" : "")"
    }
}

#Preview(as: .systemSmall) {
    ArcStatusWidget()
} timeline: {
    ArcStatusEntry(date: .now, isOpen: true, hoursLine: "Open until 12:00 AM", percent: 38)
    ArcStatusEntry(date: .now, isOpen: true, hoursLine: "Open until 12:00 AM", percent: 55, isTypical: true)
}

// MARK: - Quietest library (home + lock screen)

struct QuietestLibraryEntry: TimelineEntry {
    let date: Date
    let name: String
    let percent: Int?
    let facilityID: Int?

    init(date: Date, name: String, percent: Int?, facilityID: Int? = nil) {
        self.date = date
        self.name = name
        self.percent = percent
        self.facilityID = facilityID
    }
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
            let facilities = (try? await BusynessService().all()) ?? []
            let entry = Self.entry(from: facilities)
            let libraries = facilities.filter { $0.category == "Library" }
            let pool = libraries.isEmpty ? facilities : libraries
            let anyOpen = pool.contains(where: \.isOpen)
            let reload = WidgetRefreshMath.nextQuietestReload(
                now: .now,
                anyLibraryOpen: anyOpen,
                boundaries: [UCITime.nextIrvineMidnight()]
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> QuietestLibraryEntry {
        let facilities = (try? await BusynessService().all()) ?? []
        return Self.entry(from: facilities)
    }

    private static func entry(from facilities: [BusynessPoint]) -> QuietestLibraryEntry {
        if let pick = QuietestLibraryPick.best(from: facilities) {
            return QuietestLibraryEntry(
                date: .now,
                name: pick.title,
                percent: pick.percent,
                facilityID: pick.facilityID
            )
        }
        return QuietestLibraryEntry(
            date: .now,
            name: QuietestLibraryGlance.closedTitle,
            percent: nil
        )
    }
}

struct QuietestLibraryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsQuietestLibrary", provider: QuietestLibraryProvider()) { entry in
            QuietestLibraryView(entry: entry)
                .widgetURL(AnteatsDeepLink.study(facilityID: entry.facilityID).url)
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
                        Text(QuietestLibraryGlance.widgetRectangularDetail(percent: entry.percent))
                            .font(.system(size: 11))
                            .opacity(0.8)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    entry.percent.map {
                        "\(entry.name), \($0) percent full, quietest library right now"
                    } ?? "\(entry.name). \(QuietestLibraryGlance.closedDetail)"
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
                        Text(QuietestLibraryGlance.closedDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel(
                    entry.percent.map {
                        "\(entry.name), \($0) percent full"
                    } ?? "\(entry.name). \(QuietestLibraryGlance.closedDetail)"
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
