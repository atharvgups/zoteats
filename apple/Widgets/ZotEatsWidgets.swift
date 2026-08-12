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
            let ended = MealCountdownChrome.hasEnded(endsAt: context.state.endsAt)
            let deepLink = MealActivityDeepLink.link(
                hallID: context.attributes.hallID,
                period: context.attributes.period,
                endsAt: context.state.endsAt,
                postClosePeriod: context.state.postClosePeriod,
                postCloseDate: context.state.postCloseDate,
                opensTomorrowPeriod: context.state.opensTomorrowPeriod
            )
            // Lock screen banner.
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(activityGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.hallName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(
                        MealCountdownChrome.lockStatus(
                            period: context.attributes.period,
                            hasEnded: ended
                        )
                    )
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
                Spacer()
                if ended {
                    Text("Done")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(activityGold)
                } else {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                        .foregroundStyle(activityGold)
                }
            }
            .padding(16)
            .activityBackgroundTint(activityBlue)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                MealCountdownAccessibilityLabel.label(
                    hallName: context.attributes.hallName,
                    period: context.attributes.period,
                    endsAt: context.state.endsAt
                )
            )
            .widgetURL(deepLink.url)
        } dynamicIsland: { context in
            let ended = MealCountdownChrome.hasEnded(endsAt: context.state.endsAt)
            let deepLink = MealActivityDeepLink.link(
                hallID: context.attributes.hallID,
                period: context.attributes.period,
                endsAt: context.state.endsAt,
                postClosePeriod: context.state.postClosePeriod,
                postCloseDate: context.state.postCloseDate,
                opensTomorrowPeriod: context.state.opensTomorrowPeriod
            )
            let voiceOver = MealCountdownAccessibilityLabel.label(
                hallName: context.attributes.hallName,
                period: context.attributes.period,
                endsAt: context.state.endsAt
            )
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(activityGold)
                        Text(context.attributes.hallName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(voiceOver)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if ended {
                        Text("Done")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(activityGold)
                            .accessibilityHidden(true)
                    } else {
                        Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 84)
                            .foregroundStyle(activityGold)
                            .accessibilityHidden(true)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(
                        MealCountdownChrome.islandBottom(
                            period: context.attributes.period,
                            hasEnded: ended,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(.system(size: 12))
                        .opacity(0.8)
                        .accessibilityHidden(true)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
                    .accessibilityLabel(voiceOver)
            } compactTrailing: {
                if ended {
                    Text("Done")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activityGold)
                        .accessibilityHidden(true)
                } else {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                        .foregroundStyle(activityGold)
                        .accessibilityHidden(true)
                }
            } minimal: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
                    .accessibilityLabel(voiceOver)
            }
            .widgetURL(deepLink.url)
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
        /// Primary meal pill for Eat deep links (nil after hours without tomorrow).
        let deepLinkPeriod: String?
        /// Tomorrow ISO when after-hours row deep-links into next day's board.
        let deepLinkDate: String?

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
            deepLinkPeriod: String? = nil,
            deepLinkDate: String? = nil
        ) {
            self.id = id
            self.name = name
            self.statusText = statusText
            self.isOpen = isOpen
            self.occupancy = occupancy
            self.countdownEnd = countdownEnd
            self.countdownKind = countdownKind
            self.deepLinkPeriod = deepLinkPeriod
            self.deepLinkDate = deepLinkDate
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
            quietest: .open(name: "Science Library", percent: 12, facilityID: 2, updatedAt: .now)
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
            let (entry, locations, libraryReopenMinutes, libraryCloseMinutes) = await fetchEntryAndLocations()
            let librariesClosed: Bool = {
                if case .librariesClosed(_) = entry.quietest { return true }
                return false
            }()
            let quietestTipOpen: Bool = {
                if case .open = entry.quietest { return true }
                return false
            }()
            let reload = DiningStatusReload.nextReload(
                locations: locations,
                nowMinutes: UCITime.nowMinutes(),
                now: .now,
                librariesClosed: librariesClosed,
                libraryReopenMinutes: libraryReopenMinutes,
                libraryCloseMinutes: libraryCloseMinutes,
                quietestTipOpen: quietestTipOpen
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> DiningStatusEntry {
        await fetchEntryAndLocations().entry
    }

    private func fetchEntryAndLocations() async -> (
        entry: DiningStatusEntry,
        locations: [DiningLocation],
        libraryReopenMinutes: [Int],
        libraryCloseMinutes: [Int]
    ) {
        let locations = await DiningService().locations()
        let nowMinutes = UCITime.nowMinutes()

        let halls = locations.map { location -> DiningStatusEntry.HallStatus in
            let state = location.openState(nowMinutes: nowMinutes)
            let chrome = DiningStatusHallChrome.resolve(
                state: state,
                todayHours: location.todayHours,
                opensTomorrowAtMinutes: location.opensTomorrowAtMinutes,
                opensTomorrowPeriod: location.opensTomorrowPeriod,
                nowMinutes: nowMinutes,
                opensNextAtMinutes: location.opensNextAtMinutes,
                opensNextDayOffset: location.opensNextDayOffset,
                opensNextWeekday: location.opensNextWeekday,
                opensNextPeriod: location.opensNextPeriod
            )
            let countdownKind: DiningStatusEntry.HallStatus.CountdownKind? = {
                switch chrome.countdownKind {
                case .closes: return .closes
                case .opens: return .opens
                case nil: return nil
                }
            }()
            let link = DiningStatusDeepLink.destination(
                for: state,
                availablePeriods: location.availablePeriods,
                opensTomorrowAtMinutes: location.opensTomorrowAtMinutes,
                opensTomorrowPeriod: location.opensTomorrowPeriod,
                opensNextAtMinutes: location.opensNextAtMinutes,
                opensNextDayOffset: location.opensNextDayOffset,
                opensNextPeriod: location.opensNextPeriod,
                opensNextDateISO: location.opensNextDateISO,
                timedPeriods: location.periods,
                nowMinutes: nowMinutes
            )
            let estimate = TypicalBusyness.dining(periods: location.periods)
            let serving = location.isServing(nowMinutes: nowMinutes)
            return .init(
                id: location.id,
                name: location.name,
                statusText: chrome.statusText,
                isOpen: serving,
                occupancy: FeatureFlags.diningHallOccupancy && serving && estimate.percentNow > 0
                    ? estimate.percentNow : nil,
                countdownEnd: chrome.countdownEnd,
                countdownKind: countdownKind,
                deepLinkPeriod: link.period,
                deepLinkDate: link.date
            )
        }

        let quietest: QuietestLibraryGlance.DiningStatusTip?
        let libraryReopenMinutes: [Int]
        let libraryCloseMinutes: [Int]
        if let places = try? await BusynessService().all() {
            quietest = QuietestLibraryGlance.diningStatusTip(from: places)
            libraryReopenMinutes = QuietestLibraryReload.reopenMinutes(from: places)
            libraryCloseMinutes = QuietestLibraryReload.closeMinutes(from: places)
        } else {
            quietest = nil
            libraryReopenMinutes = []
            libraryCloseMinutes = []
        }

        return (
            DiningStatusEntry(date: .now, halls: halls, quietest: quietest),
            locations,
            libraryReopenMinutes,
            libraryCloseMinutes
        )
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
                Link(destination: AnteatsDeepLink.eat(
                    hall: hall.id,
                    period: hall.deepLinkPeriod,
                    date: hall.deepLinkDate
                ).url) {
                    hallRow(hall)
                }
            }

            if family == .systemMedium, let tip = entry.quietest {
                Divider()
                    .overlay(.white.opacity(0.25))
                switch tip {
                case .open(let name, let percent, let facilityID, _):
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
                    .accessibilityLabel(DiningStatusAccessibilityLabel.quietestTip(tip))
                case .librariesClosed(let reopenMinutes):
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
                            if let reopenMinutes {
                                Text(StudyIdleCopy.opensAtLine(minutes: reopenMinutes))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(gold.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    .accessibilityLabel(DiningStatusAccessibilityLabel.quietestTip(tip))
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
            DiningStatusAccessibilityLabel.hall(
                name: hall.name,
                statusText: hall.statusText,
                isOpen: hall.isOpen,
                occupancy: hall.occupancy,
                countdown: {
                    guard let end = hall.countdownEnd, end > Date(),
                          let kind = hall.countdownKind
                    else { return nil }
                    return kind == .closes ? .closes : .opens
                }()
            )
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
        quietest: .open(name: "Science Library", percent: 12, facilityID: 2, updatedAt: .now)
    )
}

// MARK: - Today's Menu widget (configurable hall · medium / large)

/// Dynamic hall picker — Auto + whatever `/restaurants` returns (third commons
/// appears without shipping a new AppEnum case).
struct DiningHallEntity: AppEntity, Equatable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dining Hall")
    static let defaultQuery = DiningHallEntityQuery()

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
    /// Between meals — countdown to upcoming meal start (opens, not closes).
    let periodOpensAt: Date?
    /// Extra WidgetKit reload points (meal start when still closed, etc.).
    let reloadBoundaries: [Date]
    /// Menu had dishes but Eat Filters removed every one.
    let filtersEmptiedMenu: Bool
    /// Eat deep-link period (may target tomorrow after hours).
    let deepLinkPeriod: String?
    /// Tomorrow ISO when after-hours glance deep-links into next day's board.
    let deepLinkDate: String?
    /// Tomorrow open metadata for after-hours empty copy (nil when not after hours).
    let opensTomorrowAtMinutes: Int?
    let opensTomorrowPeriod: String?
    /// Later-than-tomorrow open for after-hours empty copy (nil when not after hours).
    let opensNextAtMinutes: Int?
    let opensNextWeekday: String?
    let opensNextPeriod: String?
    /// Upcoming meal start (Irvine minutes) for empty "starts at" copy.
    let upcomingStartMinutes: Int?
    /// Partial board — Dinner may still drop; don't use after-hours empty copy.
    let awaitingMoreMeals: Bool
    /// True after published windows ended, or empty board past Lunch-probe confidence.
    let isAfterHours: Bool
    /// No timed windows today — after-hours copy must not say Dinner's done.
    let isEmptyBoard: Bool

    init(
        date: Date,
        hallName: String,
        hallID: String? = nil,
        period: String,
        dishes: [String],
        favorited: Set<String>,
        periodEndsAt: Date?,
        periodOpensAt: Date? = nil,
        reloadBoundaries: [Date] = [],
        filtersEmptiedMenu: Bool = false,
        deepLinkPeriod: String? = nil,
        deepLinkDate: String? = nil,
        opensTomorrowAtMinutes: Int? = nil,
        opensTomorrowPeriod: String? = nil,
        upcomingStartMinutes: Int? = nil,
        awaitingMoreMeals: Bool = false,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        opensNextPeriod: String? = nil,
        isAfterHours: Bool = false,
        isEmptyBoard: Bool = false
    ) {
        self.date = date
        self.hallName = hallName
        self.hallID = hallID
        self.period = period
        self.dishes = dishes
        self.favorited = favorited
        self.periodEndsAt = periodEndsAt
        self.periodOpensAt = periodOpensAt
        self.reloadBoundaries = reloadBoundaries
        self.filtersEmptiedMenu = filtersEmptiedMenu
        self.deepLinkPeriod = deepLinkPeriod
        self.deepLinkDate = deepLinkDate
        self.opensTomorrowAtMinutes = opensTomorrowAtMinutes
        self.opensTomorrowPeriod = opensTomorrowPeriod
        self.upcomingStartMinutes = upcomingStartMinutes
        self.awaitingMoreMeals = awaitingMoreMeals
        self.opensNextAtMinutes = opensNextAtMinutes
        self.opensNextWeekday = opensNextWeekday
        self.opensNextPeriod = opensNextPeriod
        self.isAfterHours = isAfterHours
        self.isEmptyBoard = isEmptyBoard
    }

    /// Opens Eat on the hall + meal this glance is showing (tomorrow after hours).
    var deepLinkURL: URL {
        let periodParam = deepLinkPeriod ?? (period.isEmpty ? nil : period)
        return AnteatsDeepLink.eat(
            hall: hallID,
            period: periodParam,
            date: deepLinkDate
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
        if let open = entry.periodOpensAt { boundaries.append(open) }
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
            hall = TodaysMenuHallPick.auto(from: locations, nowMinutes: nowMinutes)
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
        // Menu fetch + Eat deep links use the primary pill; chrome shows the
        // live API name (Brunch / Limited Dinner) like Dining Status / Island.
        let pill = choice.period
        let displayPeriod = MealPeriodDisplay.label(
            live: choice.livePeriodName,
            pill: choice.period
        )

        var dishes: [String] = []
        var favorited: Set<String> = []
        var filtersEmptiedMenu = false
        if !pill.isEmpty, let menu = try? await service.menu(for: hall.id, period: pill) {
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

        let chrome = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: choice.endsAtMinutes,
            upcomingStartMinutes: choice.upcomingStartMinutes,
            nowMinutes: nowMinutes,
            awaitingMoreMeals: choice.isAwaitingMoreMeals
        )
        let periodEndsAt = chrome.kind == .closes ? chrome.countdownEnd : nil
        let periodOpensAt = chrome.kind == .opens ? chrome.countdownEnd : nil

        let reloadBoundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes
        )

        let link: DiningStatusDeepLink.Destination
        if choice.isAfterHours {
            link = DiningStatusDeepLink.destination(
                for: .closedForToday,
                availablePeriods: hall.availablePeriods,
                opensTomorrowAtMinutes: hall.opensTomorrowAtMinutes,
                opensTomorrowPeriod: hall.opensTomorrowPeriod,
                opensNextAtMinutes: hall.opensNextAtMinutes,
                opensNextDayOffset: hall.opensNextDayOffset,
                opensNextPeriod: hall.opensNextPeriod,
                opensNextDateISO: hall.opensNextDateISO
            )
        } else {
            link = DiningStatusDeepLink.Destination(
                period: pill.isEmpty ? nil : pill
            )
        }

        return TodaysMenuEntry(
            date: .now,
            hallName: hall.name,
            hallID: hall.id,
            period: displayPeriod,
            dishes: dishes,
            favorited: favorited,
            periodEndsAt: periodEndsAt,
            periodOpensAt: periodOpensAt,
            reloadBoundaries: reloadBoundaries,
            filtersEmptiedMenu: filtersEmptiedMenu,
            deepLinkPeriod: link.period,
            deepLinkDate: link.date,
            opensTomorrowAtMinutes: choice.isAfterHours ? hall.opensTomorrowAtMinutes : nil,
            opensTomorrowPeriod: choice.isAfterHours ? hall.opensTomorrowPeriod : nil,
            upcomingStartMinutes: choice.upcomingStartMinutes,
            awaitingMoreMeals: choice.isAwaitingMoreMeals,
            opensNextAtMinutes: choice.isAfterHours ? hall.opensNextAtMinutes : nil,
            opensNextWeekday: choice.isAfterHours ? hall.opensNextWeekday : nil,
            opensNextPeriod: choice.isAfterHours ? hall.opensNextPeriod : nil,
            isAfterHours: choice.isAfterHours,
            isEmptyBoard: choice.isEmptyBoard
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
    static let title: LocalizedStringResource = "Clear Eat Filters"
    static let description = IntentDescription(
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
                Text(
                    TodaysMenuEmptyCopy.reason(
                        periodIsEmpty: entry.period.isEmpty,
                        filtersEmptiedMenu: entry.filtersEmptiedMenu,
                        opensTomorrowPeriod: entry.opensTomorrowPeriod,
                        opensTomorrowAtMinutes: entry.opensTomorrowAtMinutes,
                        surface: .glance,
                        period: entry.period,
                        upcomingStartMinutes: entry.upcomingStartMinutes,
                        awaitingMoreMeals: entry.awaitingMoreMeals,
                        opensNextPeriod: entry.opensNextPeriod,
                        opensNextAtMinutes: entry.opensNextAtMinutes,
                        opensNextWeekday: entry.opensNextWeekday,
                        isAfterHours: entry.isAfterHours,
                        emptyBoard: entry.isEmptyBoard
                    )
                )
                    .font(.system(size: 12))
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            TodaysMenuAccessibilityLabel.label(
                hallName: entry.hallName,
                period: entry.period,
                dishes: entry.dishes,
                filtersEmptiedMenu: entry.filtersEmptiedMenu,
                dishLimit: dishLimit,
                surface: .glance,
                opensTomorrowPeriod: entry.opensTomorrowPeriod,
                opensTomorrowAtMinutes: entry.opensTomorrowAtMinutes,
                awaitingMoreMeals: entry.awaitingMoreMeals,
                opensNextPeriod: entry.opensNextPeriod,
                opensNextAtMinutes: entry.opensNextAtMinutes,
                opensNextWeekday: entry.opensNextWeekday,
                isAfterHours: entry.isAfterHours,
                emptyBoard: entry.isEmptyBoard
            )
        )
    }

    private var glanceTitle: String {
        let period = entry.period.isEmpty ? "Menu" : entry.period
        let hall = entry.hallName
            .replacingOccurrences(of: "The ", with: "")
        if entry.awaitingMoreMeals, !entry.period.isEmpty {
            // Status parity — don't read like a live open meal beside last-posted dishes.
            return "\(period) · \(TodaysMenuPeriodChrome.awaitingCaptionCompact) · \(hall)"
        }
        if entry.periodOpensAt != nil {
            return "\(period) up next · \(hall)"
        }
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
                        if entry.awaitingMoreMeals {
                            Text("· \(TodaysMenuPeriodChrome.awaitingCaptionCompact)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else if let end = entry.periodEndsAt, end > Date() {
                            Text(timerInterval: Date.now...end, countsDown: true)
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                        } else if let open = entry.periodOpensAt, open > Date() {
                            Text("· opens")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                            Text(timerInterval: Date.now...open, countsDown: true)
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.16), in: Capsule())
                    .foregroundStyle(.white)
                } else if entry.awaitingMoreMeals {
                    Text(TodaysMenuPeriodChrome.awaitingCaption)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: Capsule())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
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
                        TodaysMenuEmptyCopy.reason(
                            periodIsEmpty: entry.period.isEmpty,
                            filtersEmptiedMenu: false,
                            opensTomorrowPeriod: entry.opensTomorrowPeriod,
                            opensTomorrowAtMinutes: entry.opensTomorrowAtMinutes,
                            surface: .home,
                            period: entry.period,
                            upcomingStartMinutes: entry.upcomingStartMinutes,
                            awaitingMoreMeals: entry.awaitingMoreMeals,
                            opensNextPeriod: entry.opensNextPeriod,
                            opensNextAtMinutes: entry.opensNextAtMinutes,
                            opensNextWeekday: entry.opensNextWeekday,
                            isAfterHours: entry.isAfterHours,
                            emptyBoard: entry.isEmptyBoard
                        ) + "."
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
            TodaysMenuAccessibilityLabel.label(
                hallName: entry.hallName,
                period: entry.period,
                dishes: entry.dishes,
                filtersEmptiedMenu: entry.filtersEmptiedMenu,
                dishLimit: dishLimit,
                surface: .home,
                opensTomorrowPeriod: entry.opensTomorrowPeriod,
                opensTomorrowAtMinutes: entry.opensTomorrowAtMinutes,
                awaitingMoreMeals: entry.awaitingMoreMeals,
                opensNextPeriod: entry.opensNextPeriod,
                opensNextAtMinutes: entry.opensNextAtMinutes,
                opensNextWeekday: entry.opensNextWeekday,
                isAfterHours: entry.isAfterHours,
                emptyBoard: entry.isEmptyBoard
            )
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
        .accessibilityLabel(
            CampusOpenAccessibilityLabel.label(
                totalOpen: entry.totalOpen,
                openPlaceNames: entry.openPlaces.map { $0.name },
                nextOpenLine: entry.nextOpen?.line
            )
        )
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
    /// True when hours come from the maintained schedule (Waitz hours missing).
    let hoursApproximate: Bool
    /// Waitz snapshot time for live crowding VoiceOver freshness (nil when typical / none).
    let liveUpdatedAt: Date?

    init(
        date: Date,
        isOpen: Bool,
        hoursLine: String,
        percent: Int?,
        isTypical: Bool = false,
        hoursApproximate: Bool = false,
        liveUpdatedAt: Date? = nil
    ) {
        self.date = date
        self.isOpen = isOpen
        self.hoursLine = hoursLine
        self.percent = percent
        self.isTypical = isTypical
        self.hoursApproximate = hoursApproximate
        self.liveUpdatedAt = liveUpdatedAt
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
            let status = await GymService().status()
            let entry = Self.entry(from: status)
            let reload = GymBoundaryRefresh.nextFire(
                now: .now,
                reopenMinutes: status.waitzReopenMinutes,
                closeMinutes: status.waitzCloseMinutes
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> ArcStatusEntry {
        Self.entry(from: await GymService().status())
    }

    private static func entry(from status: GymStatus) -> ArcStatusEntry {
        let nowMinutes = UCITime.nowMinutes()
        let weekday = UCITime.weekdayName()
        let hoursLine = ArcIdleCopy.hoursLine(
            openNow: status.openNow,
            todayHours: status.todayHours,
            nowMinutes: nowMinutes,
            opensAtMinutesToday: ArcIdleCopy.opensAtMinutesToday(
                weekday: weekday,
                openNow: status.openNow,
                waitzReopenMinutes: status.waitzReopenMinutes
            ),
            closesAtMinutesToday: ArcIdleCopy.closesAtMinutesToday(
                weekday: weekday,
                openNow: status.openNow,
                nowMinutes: nowMinutes,
                waitzCloseMinutes: status.waitzCloseMinutes,
                waitzReopenMinutes: status.waitzReopenMinutes
            ),
            opensAtMinutesTomorrow: ArcIdleCopy.opensAtMinutesTomorrow(
                weekday: weekday,
                openNow: status.openNow,
                nowMinutes: nowMinutes,
                waitzReopenMinutes: status.waitzReopenMinutes
            )
        )
        let crowding = ArcWidgetGlance.crowding(from: status)
        let isTypical = crowding?.isTypical ?? false
        let liveUpdatedAt: Date? = {
            guard crowding != nil, !isTypical else { return nil }
            return status.busyness?.updatedAt
        }()
        return ArcStatusEntry(
            date: .now,
            isOpen: status.openNow,
            hoursLine: hoursLine,
            percent: crowding?.percent,
            isTypical: isTypical,
            hoursApproximate: status.hoursApproximate,
            liveUpdatedAt: liveUpdatedAt
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
                    .accessibilityLabel(arcAccessibilityLabel)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(entry.isOpen ? "Open" : "Closed")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .accessibilityLabel(arcAccessibilityLabel)
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
                .accessibilityLabel(arcAccessibilityLabel)
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
                    Text(displayHoursLine)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .accessibilityLabel(arcAccessibilityLabel)
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

    /// Sighted cue when hours are schedule-maintained (widget has no footnote).
    private var displayHoursLine: String {
        guard entry.hoursApproximate,
              !entry.hoursLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return entry.hoursLine }
        return "\(entry.hoursLine) · approx"
    }

    private var rectangularDetail: String {
        guard let percent = entry.percent else { return displayHoursLine }
        let source = entry.isTypical ? "typical" : "live"
        return "\(percent)% · \(source) · \(displayHoursLine)"
    }

    private var arcAccessibilityLabel: String {
        let updatedRelative = entry.liveUpdatedAt.map { UpdatedAgoCopy.relative(from: $0) }
        return ArcWidgetAccessibilityLabel.label(
            isOpen: entry.isOpen,
            hoursLine: entry.hoursLine,
            percent: entry.percent,
            isTypical: entry.isTypical,
            hoursApproximate: entry.hoursApproximate,
            updatedRelative: updatedRelative
        )
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
    /// Waitz snapshot for open picks (VoiceOver Updated freshness).
    let updatedAt: Date?
    /// Waitz Closed-until reopen (Irvine minutes) when libraries are shut.
    let reopenMinutes: Int?

    init(
        date: Date,
        name: String,
        percent: Int?,
        facilityID: Int? = nil,
        updatedAt: Date? = nil,
        reopenMinutes: Int? = nil
    ) {
        self.date = date
        self.name = name
        self.percent = percent
        self.facilityID = facilityID
        self.updatedAt = updatedAt
        self.reopenMinutes = reopenMinutes
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
            let nowMinutes = UCITime.nowMinutes()
            let anyOpen = StudyBoundaryRefresh.anyLibraryOpen(
                from: facilities,
                nowMinutes: nowMinutes
            )
            let reload = QuietestLibraryReload.nextReload(
                now: .now,
                anyLibraryOpen: anyOpen,
                reopenMinutes: QuietestLibraryReload.reopenMinutes(from: facilities),
                closeMinutes: QuietestLibraryReload.closeMinutes(
                    from: facilities,
                    nowMinutes: nowMinutes
                )
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
                facilityID: pick.facilityID,
                updatedAt: pick.updatedAt
            )
        }
        return QuietestLibraryEntry(
            date: .now,
            name: QuietestLibraryGlance.closedTitle,
            percent: nil,
            reopenMinutes: StudyIdleCopy.soonestReopenMinutes(from: facilities)
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
                    .accessibilityLabel(quietestAccessibilityLabel(includeQuietestQualifier: false))
                } else {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .accessibilityLabel(quietestAccessibilityLabel(includeQuietestQualifier: false))
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(QuietestLibraryGlance.widgetRectangularDetail(
                            percent: entry.percent,
                            reopenMinutes: entry.reopenMinutes
                        ))
                            .font(.system(size: 11))
                            .opacity(0.8)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(quietestAccessibilityLabel(includeQuietestQualifier: true))
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
                        Text(
                            StudyIdleCopy.quietestClosedDetail(reopenMinutes: entry.reopenMinutes)
                        )
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel(quietestAccessibilityLabel(includeQuietestQualifier: false))
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

    private func quietestAccessibilityLabel(includeQuietestQualifier: Bool) -> String {
        let updatedRelative: String? = {
            guard entry.percent != nil, let updatedAt = entry.updatedAt else { return nil }
            return UpdatedAgoCopy.relative(from: updatedAt)
        }()
        return QuietestLibraryAccessibilityLabel.label(
            name: entry.name,
            percent: entry.percent,
            includeQuietestQualifier: includeQuietestQualifier,
            updatedRelative: updatedRelative,
            reopenMinutes: entry.reopenMinutes
        )
    }
}

#Preview(as: .accessoryCircular) {
    QuietestLibraryWidget()
} timeline: {
    QuietestLibraryEntry(date: .now, name: "Langson · 4th Floor", percent: 8)
}
