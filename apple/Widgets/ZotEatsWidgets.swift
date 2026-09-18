import WidgetKit
import SwiftUI
import UIKit
import ActivityKit
import AppIntents
import ZotEatsKit

// Home-screen + lock-screen widgets for Anteats.
// Tight gallery (~7 surfaces), each one story: Dining Halls small + lock,
// Today's Menu medium, Favorites Today small, Campus Open Now small + medium,
// Quietest Library small. Live Activity stays. Gym / Campus+Study are cut.
//
// CRITICAL: every glance root uses `.unredacted()`. Without it, WidgetKit can
// leave Home Screen widgets stuck on system redacted placeholder bars (colored
// dots visible, hall names / menus barred) — especially after cold install
// while the timeline is still loading. Pair with App Group `WidgetSnapshotStore`
// so timelines paint real strings immediately after the user opens the app once.

@main
struct ZotEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Keep flat — nested WidgetBundles no longer type-check as Widget.
        DiningStatusWidget()
        TodaysMenuWidget()
        FavoritesTodayWidget()
        CampusOpenWidget()
        QuietestLibraryWidget()
        MealCountdownActivity()
    }
}

/// Forces readable strings on Home Screen — see file header.
private extension View {
    func anteatsWidgetContent() -> some View {
        self.unredacted()
    }
}

/// Home Screen widget chrome — editorial, thick SF Pro, gold accent.
/// One glance per size. Colors follow Home Screen light/dark.
private enum WidgetChrome {
    static let open = Color(red: 1 / 255, green: 168 / 255, blue: 88 / 255)

    static let canvas = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 10 / 255, green: 10 / 255, blue: 11 / 255, alpha: 1)
        }
        return UIColor(red: 252 / 255, green: 251 / 255, blue: 248 / 255, alpha: 1)
    })

    static let padding: CGFloat = 16

    static let ink = Color(uiColor: .label)

    static let muted = Color(uiColor: .secondaryLabel)

    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 0.12)
    })

    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 210 / 255, blue: 0 / 255, alpha: 1)
            : UIColor(red: 176 / 255, green: 118 / 255, blue: 0 / 255, alpha: 1)
    })

    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func kicker(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func row(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func meta(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }
}

private struct WidgetKicker: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(WidgetChrome.kicker(12))
                .tracking(1.1)
                .foregroundStyle(WidgetChrome.accent)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(WidgetChrome.kicker(12))
                    .tracking(0.6)
                    .foregroundStyle(WidgetChrome.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct WidgetHairline: View {
    var body: some View {
        WidgetChrome.hairline
            .frame(height: 1)
    }
}

private let activityBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
private let activityGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

// MARK: - "Meal ends soon" Live Activity

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
                        .font(WidgetChrome.row(15))
                    Text(
                        MealCountdownChrome.lockStatus(
                            period: context.attributes.period,
                            hasEnded: ended,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(WidgetChrome.meta(12))
                        .opacity(0.8)
                }
                Spacer()
                if ended {
                    Text(
                        MealCountdownChrome.compactTrailing(
                            period: context.attributes.period,
                            hasEnded: true,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(WidgetChrome.display(22))
                        .foregroundStyle(activityGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                        .font(WidgetChrome.display(28))
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
            .unredacted()
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
                            .font(WidgetChrome.row(14))
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(voiceOver)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if ended {
                        Text(
                            MealCountdownChrome.compactTrailing(
                                period: context.attributes.period,
                                hasEnded: true,
                                postClosePeriod: context.state.postClosePeriod,
                                postCloseDate: context.state.postCloseDate
                            )
                        )
                            .font(WidgetChrome.display(18))
                            .foregroundStyle(activityGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityHidden(true)
                    } else {
                        Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                            .font(WidgetChrome.display(22))
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
                        .font(WidgetChrome.meta(12))
                        .opacity(0.8)
                        .accessibilityHidden(true)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
                    .accessibilityLabel(voiceOver)
            } compactTrailing: {
                if ended {
                    Text(
                        MealCountdownChrome.compactTrailing(
                            period: context.attributes.period,
                            hasEnded: true,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(WidgetChrome.row(12))
                        .foregroundStyle(activityGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
    /// True when we have no halls to show — render honest refresh copy (never skeleton).
    let needsAppRefresh: Bool
    let boardHallName: String?
    let boardHallID: String?
    let boardDishes: [String]
    let campusOpen: [WidgetGlanceExtras.CampusRow]
    let campusOpenCount: Int

    init(
        date: Date,
        halls: [HallStatus],
        quietest: QuietestLibraryGlance.DiningStatusTip? = nil,
        needsAppRefresh: Bool = false,
        boardHallName: String? = nil,
        boardHallID: String? = nil,
        boardDishes: [String] = [],
        campusOpen: [WidgetGlanceExtras.CampusRow] = [],
        campusOpenCount: Int = 0
    ) {
        self.date = date
        self.halls = halls
        self.quietest = quietest
        self.needsAppRefresh = needsAppRefresh
        self.boardHallName = boardHallName
        self.boardHallID = boardHallID
        self.boardDishes = boardDishes
        self.campusOpen = campusOpen
        self.campusOpenCount = campusOpenCount
    }

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
        let isComingSoon: Bool

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
            deepLinkDate: String? = nil,
            isComingSoon: Bool = false
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
            self.isComingSoon = isComingSoon
        }
    }
}

struct DiningHallsConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dining Halls"
    static let description: IntentDescription = IntentDescription(
        "Three hall clocks — open now or what’s up next. Hide Coming Soon if you want."
    )

    @Parameter(title: "Show Coming Soon halls", default: true)
    var showComingSoon: Bool
}

private enum DiningStatusPaint {
    /// Sync App Group paint — WidgetKit `placeholder` cannot await the network.
    static func fromDisk(showComingSoon: Bool) -> DiningStatusEntry? {
        guard let locations = WidgetSnapshotStore.loadDiningLocationsIfCurrentDay(),
              !locations.isEmpty
        else { return nil }
        return makeEntry(
            locations: locations,
            waitzPlaces: WidgetSnapshotStore.loadBusynessPlacesIfPresent() ?? [],
            campusPlaces: WidgetSnapshotStore.loadCampusPlacesIfCurrentDay() ?? [],
            showComingSoon: showComingSoon,
            allowTypicalOccupancy: false
        )
    }

    /// Widget gallery shape only — hall occupancy and quietest % stay nil.
    static func gallerySample() -> DiningStatusEntry {
        DiningStatusEntry(
            date: .now,
            halls: [
                .init(
                    id: "anteatery",
                    name: "The Anteatery",
                    statusText: "Lunch · 11:30 AM",
                    isOpen: false,
                    occupancy: WidgetPlaceholderHonesty.galleryHallOccupancy,
                    countdownEnd: nil,
                    countdownKind: nil
                ),
                .init(
                    id: "brandywine",
                    name: "Brandywine",
                    statusText: "Breakfast · 11:00 AM",
                    isOpen: true,
                    occupancy: WidgetPlaceholderHonesty.galleryHallOccupancy,
                    countdownEnd: .now.addingTimeInterval(5400),
                    countdownKind: .closes
                ),
                .init(
                    id: "oasis",
                    name: "The Oasis",
                    statusText: "Coming Soon",
                    isOpen: false,
                    occupancy: WidgetPlaceholderHonesty.galleryHallOccupancy,
                    countdownEnd: nil,
                    countdownKind: nil,
                    isComingSoon: true
                ),
            ],
            quietest: nil,
            boardHallName: "Brandywine",
            boardHallID: "brandywine",
            boardDishes: ["Crispy Okra", "Farro Salad", "BBQ Pork"],
            campusOpen: [
                .init(id: "starbucks-at-student-center", name: "Starbucks", hours: "until 4 PM"),
            ],
            campusOpenCount: 6
        )
    }

    static func makeEntry(
        locations: [DiningLocation],
        waitzPlaces: [BusynessPoint],
        campusPlaces: [CampusPlace],
        showComingSoon: Bool,
        nowMinutes: Int = UCITime.nowMinutes(),
        allowTypicalOccupancy: Bool
    ) -> DiningStatusEntry {
        guard !locations.isEmpty else {
            return DiningStatusEntry(date: .now, halls: [], needsAppRefresh: true)
        }

        let visibleLocations = WidgetGlanceExtras.comingSoonHalls(
            from: locations,
            showComingSoon: showComingSoon
        )

        let halls = visibleLocations.map { location -> DiningStatusEntry.HallStatus in
            if location.isComingSoon {
                return .init(
                    id: location.id,
                    name: location.name,
                    statusText: location.comingSoonSubtitle ?? "Coming Soon",
                    isOpen: false,
                    occupancy: nil,
                    countdownEnd: nil,
                    countdownKind: nil,
                    deepLinkPeriod: nil,
                    deepLinkDate: nil,
                    isComingSoon: true
                )
            }
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
                statusText: DiningStatusWidgetLine.resolve(
                    state: state,
                    todayHours: location.todayHours,
                    opensTomorrowAtMinutes: location.opensTomorrowAtMinutes,
                    opensTomorrowPeriod: location.opensTomorrowPeriod,
                    opensNextAtMinutes: location.opensNextAtMinutes,
                    opensNextWeekday: location.opensNextWeekday,
                    opensNextPeriod: location.opensNextPeriod
                ),
                isOpen: serving,
                occupancy: allowTypicalOccupancy && serving && estimate.percentNow > 0
                    ? estimate.percentNow : nil,
                countdownEnd: chrome.countdownEnd,
                countdownKind: countdownKind,
                deepLinkPeriod: link.period,
                deepLinkDate: link.date
            )
        }

        let quietest: QuietestLibraryGlance.DiningStatusTip? = waitzPlaces.isEmpty
            ? nil
            : QuietestLibraryGlance.diningStatusTip(from: waitzPlaces)

        var boardHallName: String?
        var boardHallID: String?
        var boardDishes: [String] = []
        if let pick = TodaysMenuHallPick.auto(from: locations, nowMinutes: nowMinutes) {
            let timed = pick.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
            let choice = TodaysMenuPeriodPick.choose(
                timedPeriods: timed,
                availablePeriods: pick.availablePeriods,
                nowMinutes: nowMinutes
            )
            if !choice.period.isEmpty {
                let menu = WidgetSnapshotStore.loadDiningMenu(
                    hall: pick.id,
                    period: choice.period,
                    dateISO: UCITime.todayISO()
                )
                if let strip = WidgetGlanceExtras.boardStrip(
                    locations: locations,
                    menu: menu,
                    nowMinutes: nowMinutes,
                    dietFilters: Set(SharedDefaults.dietFilters()),
                    allergenAvoids: Set(SharedDefaults.allergenAvoids()),
                    favorites: SharedDefaults.favoriteDishNames(),
                    limit: 5
                ) {
                    boardHallName = strip.hallName
                    boardHallID = strip.hallID
                    boardDishes = strip.dishes
                }
            }
        }

        let campus = WidgetGlanceExtras.campusRows(
            places: campusPlaces,
            favoriteIDs: Set(SharedDefaults.favoriteCampusPlaceIDs()),
            favoritesOnly: false,
            limit: 3
        )

        return DiningStatusEntry(
            date: .now,
            halls: halls,
            quietest: quietest,
            boardHallName: boardHallName,
            boardHallID: boardHallID,
            boardDishes: boardDishes,
            campusOpen: campus.rows,
            campusOpenCount: campus.totalOpen
        )
    }
}

struct DiningStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DiningStatusEntry {
        placeholder(for: DiningHallsConfigurationIntent(), in: context)
    }

    func placeholder(for configuration: DiningHallsConfigurationIntent, in context: Context) -> DiningStatusEntry {
        let cached = DiningStatusPaint.fromDisk(showComingSoon: configuration.showComingSoon)
        switch WidgetPlaceholderHonesty.source(
            hasSnapshot: cached != nil,
            isPreview: context.isPreview
        ) {
        case .snapshot:
            return cached!
        case .gallery:
            return DiningStatusPaint.gallerySample()
        case .needsRefresh:
            return DiningStatusEntry(date: .now, halls: [], needsAppRefresh: true)
        }
    }

    func snapshot(for configuration: DiningHallsConfigurationIntent, in context: Context) async -> DiningStatusEntry {
        if context.isPreview {
            if let cached = DiningStatusPaint.fromDisk(showComingSoon: configuration.showComingSoon) {
                return cached
            }
            return DiningStatusPaint.gallerySample()
        }
        return await fetchEntry(showComingSoon: configuration.showComingSoon)
    }

    func timeline(for configuration: DiningHallsConfigurationIntent, in context: Context) async -> Timeline<DiningStatusEntry> {
        let (entry, locations, libraryReopenMinutes, libraryCloseMinutes) = await fetchEntryAndLocations(
            showComingSoon: configuration.showComingSoon
        )
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
        return Timeline(entries: [entry], policy: .after(reload))
    }

    private func fetchEntry(showComingSoon: Bool) async -> DiningStatusEntry {
        await fetchEntryAndLocations(showComingSoon: showComingSoon).entry
    }

    private func fetchEntryAndLocations(showComingSoon: Bool) async -> (
        entry: DiningStatusEntry,
        locations: [DiningLocation],
        libraryReopenMinutes: [Int],
        libraryCloseMinutes: [Int]
    ) {
        // Cache-first: today's App Group snapshot paints real hall names
        // immediately; network only runs when that snapshot is missing.
        async let locationsTask = WidgetSnapshotPaint.diningLocations()
        async let waitzTask = WidgetSnapshotPaint.busynessPlaces()
        async let campusTask = WidgetSnapshotPaint.campusPlaces()
        let locations = await locationsTask
        let waitzPlaces = await waitzTask
        let campusPlaces = await campusTask

        let entry = DiningStatusPaint.makeEntry(
            locations: locations,
            waitzPlaces: waitzPlaces,
            campusPlaces: campusPlaces,
            showComingSoon: showComingSoon,
            allowTypicalOccupancy: FeatureFlags.diningHallOccupancy
        )
        let libraryReopenMinutes = waitzPlaces.isEmpty
            ? []
            : QuietestLibraryReload.reopenMinutes(from: waitzPlaces)
        let libraryCloseMinutes = waitzPlaces.isEmpty
            ? []
            : QuietestLibraryReload.closeMinutes(from: waitzPlaces)
        return (entry, locations, libraryReopenMinutes, libraryCloseMinutes)
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
        AppIntentConfiguration(
            kind: WidgetTimelineKinds.diningStatus,
            intent: DiningHallsConfigurationIntent.self,
            provider: DiningStatusProvider()
        ) { entry in
            DiningStatusView(entry: entry)
                .anteatsWidgetContent()
                .widgetURL(AnteatsWidgetURL.eat)
        }
        .configurationDisplayName("Dining Halls")
        .description("Next meal at each hall — open now or what’s up next.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
        ])
    }
}

/// Deep links into the app when a widget is tapped.
private enum AnteatsWidgetURL {
    static let eat = AnteatsDeepLink.eat().url
    static let campus = AnteatsDeepLink.campus(placeID: nil).url
    static let study = AnteatsDeepLink.study().url
}

struct DiningStatusView: View {
    let entry: DiningStatusEntry
    @Environment(\.widgetFamily) private var family

    private var isCompact: Bool { family == .systemSmall || isAccessory }
    private var isLarge: Bool { family == .systemLarge }
    private var isAccessory: Bool {
        switch family {
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            return true
        default:
            return false
        }
    }
    private var visibleHalls: ArraySlice<DiningStatusEntry.HallStatus> {
        entry.halls.prefix(DiningStatusLayout.hallLimit(isCompact: isCompact, isLarge: isLarge))
    }
    private var hallCount: Int { visibleHalls.count }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                lockCircular
            case .accessoryRectangular:
                lockGlance
            default:
                homeScreen
            }
        }
        .containerBackground(for: .widget) {
            isAccessory ? Color.clear : WidgetChrome.canvas
        }
    }

    private var homeScreen: some View {
        let spacing = DiningStatusLayout.rowSpacing(isCompact: isCompact, hallCount: hallCount)
        return VStack(alignment: .leading, spacing: spacing) {
            WidgetKicker(title: "EAT")

            if entry.needsAppRefresh || entry.halls.isEmpty {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(16))
                    .foregroundStyle(WidgetChrome.ink)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(13))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleHalls.enumerated()), id: \.element.id) { index, hall in
                        if index > 0 { WidgetHairline().padding(.vertical, 5) }
                        Link(destination: AnteatsDeepLink.eat(
                            hall: hall.id,
                            period: hall.deepLinkPeriod,
                            date: hall.deepLinkDate
                        ).url) {
                            hallRow(hall)
                        }
                    }
                }
                if DiningStatusLayout.showsBoardStrip(isCompact: isCompact) {
                    boardStrip
                }
                if isLarge {
                    campusStrip
                    studyStrip
                }
                Spacer(minLength: 0)
            }
        }
        .padding(WidgetChrome.padding)
    }

    /// Lock Screen — three clocks, nothing else.
    private var lockGlance: some View {
        VStack(alignment: .leading, spacing: 5) {
            if entry.needsAppRefresh || entry.halls.isEmpty {
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(14))
                    .lineLimit(2)
            } else {
                ForEach(Array(visibleHalls.prefix(3)), id: \.id) { hall in
                    let raw = DiningStatusWidgetLine.tighten(hall.statusText)
                    let split = DiningStatusWidgetLine.splitMealAndClock(raw)
                    let clock = hall.isComingSoon ? "Soon" : (split.clock ?? split.meal)
                    HStack(spacing: 6) {
                        Text(shortName(hall.name))
                            .font(WidgetChrome.row(14))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(clock)
                            .font(WidgetChrome.display(16))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    private var lockCircular: some View {
        let focus = visibleHalls.first(where: { $0.isOpen }) ?? visibleHalls.first
        let raw = focus.map { DiningStatusWidgetLine.tighten($0.statusText) } ?? ""
        let split = DiningStatusWidgetLine.splitMealAndClock(raw)
        let meal = focus?.isComingSoon == true ? "Soon" : (split.meal.isEmpty ? "Eat" : split.meal)
        return VStack(spacing: 2) {
            Text(meal)
                .font(WidgetChrome.display(14))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let focus {
                Text(shortName(focus.name))
                    .font(WidgetChrome.meta(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    @ViewBuilder
    private var boardStrip: some View {
        if !entry.boardDishes.isEmpty {
            let dishes = Array(entry.boardDishes.prefix(DiningStatusLayout.boardDishLimit(isLarge: isLarge)))
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.boardHallName ?? "Board")
                    .font(WidgetChrome.kicker(12))
                    .foregroundStyle(WidgetChrome.accent)
                ForEach(dishes, id: \.self) { dish in
                    Link(destination: AnteatsDeepLink.eat(
                        hall: entry.boardHallID,
                        dish: dish
                    ).url) {
                        Text(dish)
                            .font(WidgetChrome.row(15))
                            .foregroundStyle(WidgetChrome.ink)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var campusStrip: some View {
        if DiningStatusLayout.showsCampusStrip(isLarge: isLarge), !entry.campusOpen.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                WidgetKicker(
                    title: "CAMPUS",
                    trailing: entry.campusOpenCount == 0 ? nil : "\(entry.campusOpenCount) OPEN"
                )
                ForEach(Array(entry.campusOpen.prefix(DiningStatusLayout.campusRowLimit(isLarge: true))), id: \.id) { place in
                    Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                        HStack {
                            Text(place.name)
                                .font(WidgetChrome.row(14))
                                .foregroundStyle(WidgetChrome.ink)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(place.hours)
                                .font(WidgetChrome.meta(13))
                                .foregroundStyle(WidgetChrome.accent)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var studyStrip: some View {
        if DiningStatusLayout.showsStudyFooter(isCompact: isCompact, isLarge: isLarge),
           let quietest = entry.quietest {
            switch quietest {
            case .open(let name, let percent, let facilityID, _):
                Link(destination: AnteatsDeepLink.study(facilityID: facilityID).url) {
                    HStack {
                        Text("STUDY")
                            .font(WidgetChrome.kicker(12))
                            .foregroundStyle(WidgetChrome.accent)
                        Spacer(minLength: 4)
                        Text("\(name) · \(percent)%")
                            .font(WidgetChrome.row(14))
                            .foregroundStyle(WidgetChrome.ink)
                            .lineLimit(1)
                    }
                }
            case .librariesClosed:
                Text("Libraries closed")
                    .font(WidgetChrome.row(14))
                    .foregroundStyle(WidgetChrome.muted)
            }
        }
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        let nameSize = DiningStatusLayout.nameFontSize(isCompact: isCompact, hallCount: hallCount)
        let clockSize = DiningStatusLayout.statusFontSize(isCompact: isCompact, hallCount: hallCount)
        let raw = isCompact ? DiningStatusWidgetLine.tighten(hall.statusText) : hall.statusText
        let split = DiningStatusWidgetLine.splitMealAndClock(raw)
        let subtitle: String = {
            if isCompact { return "" }
            if hall.isComingSoon { return "Soon" }
            if split.clock != nil { return split.meal }
            return ""
        }()
        let trailing: String = {
            if hall.isComingSoon { return "Soon" }
            return split.clock ?? split.meal
        }()
        return HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(hall.isOpen ? WidgetChrome.open : WidgetChrome.muted.opacity(0.45))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(shortName(hall.name))
                    .font(WidgetChrome.row(nameSize))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(WidgetChrome.meta(13))
                        .foregroundStyle(WidgetChrome.muted)
                        .lineLimit(1)
                }
            }
            Text(trailing)
                .font(WidgetChrome.hero(clockSize))
                .foregroundStyle(hall.isOpen ? WidgetChrome.accent : WidgetChrome.muted)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: DiningStatusLayout.trailingColumnMinWidth, alignment: .trailing)
        }
        .opacity(hall.isOpen || hall.isComingSoon ? 1 : 0.78)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            DiningStatusAccessibilityLabel.hall(
                name: hall.name,
                statusText: hall.statusText,
                isOpen: hall.isOpen,
                occupancy: hall.occupancy,
                countdown: nil
            )
        )
    }

    /// "The Anteatery" -> "Anteatery" for tight widget rows.
    private func shortName(_ name: String) -> String {
        name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
    }
}

#Preview(as: .systemSmall) {
    DiningStatusWidget()
} timeline: {
    DiningStatusEntry(
        date: .now,
        halls: [
            .init(id: "anteatery", name: "The Anteatery", statusText: "Lunch · 11:30 AM", isOpen: false, occupancy: nil, countdownEnd: nil, countdownKind: nil),
            .init(id: "brandywine", name: "Brandywine", statusText: "Breakfast · 11:00 AM", isOpen: true, occupancy: nil, countdownEnd: nil, countdownKind: .closes),
            .init(id: "oasis", name: "The Oasis", statusText: "Coming Soon", isOpen: false, occupancy: nil, countdownEnd: nil, countdownKind: nil, isComingSoon: true),
        ],
        boardHallName: "Brandywine",
        boardHallID: "brandywine",
        boardDishes: ["Crispy Okra", "Farro Salad", "BBQ Pork"]
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

private enum WidgetSnapshotPaint {
    private static let http = HTTPClient(timeout: 8)
    private static let waitzHTTP = HTTPClient(timeout: 6)

    static func diningService() -> DiningService {
        DiningService(http: http)
    }

    static func diningLocations() async -> [DiningLocation] {
        if let cached = WidgetSnapshotStore.loadDiningLocationsIfCurrentDay() {
            Task { await refreshDiningLocations() }
            return cached
        }
        return await refreshDiningLocations()
    }

    @discardableResult
    private static func refreshDiningLocations() async -> [DiningLocation] {
        let networked = await DiningService(http: http).locations()
        let networkLooksLive = networked.contains {
            !$0.availablePeriods.isEmpty || $0.todayHours != nil || !$0.periods.isEmpty
        }
        if networkLooksLive {
            WidgetSnapshotStore.saveDiningLocations(networked)
            return networked
        }
        return WidgetSnapshotStore.loadDiningLocations() ?? networked
    }

    static func campusPlaces() async -> [CampusPlace] {
        if let cached = WidgetSnapshotStore.loadCampusPlacesIfCurrentDay() {
            Task { await refreshCampusPlaces() }
            return cached
        }
        return await refreshCampusPlaces()
    }

    @discardableResult
    private static func refreshCampusPlaces() async -> [CampusPlace] {
        let cached = WidgetSnapshotStore.loadCampusPlaces() ?? []
        if let networked = try? await CampusService(http: http).places(),
           !networked.isEmpty {
            WidgetSnapshotStore.saveCampusPlaces(networked)
            return networked
        }
        return cached
    }

    static func busynessPlaces() async -> [BusynessPoint] {
        if let cached = WidgetSnapshotStore.loadBusynessPlacesIfPresent() {
            Task { await refreshBusynessPlaces() }
            return cached
        }
        return await refreshBusynessPlaces()
    }

    @discardableResult
    private static func refreshBusynessPlaces() async -> [BusynessPoint] {
        let cached = WidgetSnapshotStore.loadBusynessPlaces() ?? []
        if let networked = try? await BusynessService(http: waitzHTTP).all(),
           !networked.isEmpty {
            WidgetSnapshotStore.saveBusynessPlaces(networked)
            return networked
        }
        return cached
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
        let locations = await WidgetSnapshotPaint.diningLocations()
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
    /// Compact Eat Filters hint (e.g. "Vegan · −Peanuts") when filters are on.
    let filterHint: String?

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
        isEmptyBoard: Bool = false,
        filterHint: String? = nil
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
        self.filterHint = filterHint
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

    /// Per-dish tap — same hall/meal/date as the glance, plus the dish name.
    func dishDeepLinkURL(_ dish: String) -> URL {
        let periodParam = deepLinkPeriod ?? (period.isEmpty ? nil : period)
        return AnteatsDeepLink.eat(
            hall: hallID,
            period: periodParam,
            dish: dish,
            date: deepLinkDate
        ).url
    }
}

struct TodaysMenuProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodaysMenuEntry {
        let menus = WidgetSnapshotStore.loadDiningMenusIfCurrentDay()
        let hasSnapshot = !menus.isEmpty
        switch WidgetPlaceholderHonesty.source(hasSnapshot: hasSnapshot, isPreview: context.isPreview) {
        case .snapshot:
            if let menu = menus.first, !menu.stations.isEmpty {
                let dishes = menu.stations.flatMap(\.items).map(\.name)
                return TodaysMenuEntry(
                    date: .now,
                    hallName: HallDirectory.displayName(for: menu.locationId),
                    hallID: menu.locationId,
                    period: menu.period,
                    dishes: Array(dishes.prefix(5)),
                    favorited: [],
                    periodEndsAt: nil
                )
            }
            return Self.gallerySample()
        case .gallery:
            return Self.gallerySample()
        case .needsRefresh:
            return TodaysMenuEntry(
                date: .now,
                hallName: WidgetLoadEmptyCopy.title,
                hallID: nil,
                period: "",
                dishes: [],
                favorited: [],
                periodEndsAt: nil
            )
        }
    }

    private static func gallerySample() -> TodaysMenuEntry {
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
        let service = WidgetSnapshotPaint.diningService()
        let locations = await WidgetSnapshotPaint.diningLocations()
        let nowMinutes = UCITime.nowMinutes()

        let hall: DiningLocation?
        if let id = configuration.hall.hallID {
            hall = locations.first { $0.id == id } ?? locations.first
        } else {
            hall = TodaysMenuHallPick.auto(from: locations, nowMinutes: nowMinutes)
        }
        guard let hall else {
            return TodaysMenuEntry(
                date: .now,
                hallName: WidgetLoadEmptyCopy.title,
                period: "",
                dishes: [],
                favorited: [],
                periodEndsAt: nil
            )
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
        if !pill.isEmpty {
            let todayISO = UCITime.todayISO()
            let cachedMenu = WidgetSnapshotStore.loadDiningMenu(
                hall: hall.id,
                period: pill,
                dateISO: todayISO
            )
            let menu: DiningMenu?
            if let cachedMenu, !cachedMenu.stations.isEmpty {
                menu = cachedMenu
                let hallID = hall.id
                Task {
                    if let networkedMenu = try? await WidgetSnapshotPaint.diningService()
                        .menu(for: hallID, period: pill) {
                        WidgetSnapshotStore.saveDiningMenu(networkedMenu)
                    }
                }
            } else {
                let networkedMenu = try? await service.menu(for: hall.id, period: pill)
                if let networkedMenu {
                    WidgetSnapshotStore.saveDiningMenu(networkedMenu)
                }
                menu = networkedMenu ?? cachedMenu
            }
            if let menu {
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

        let filterHint = EatFilterHint.label(
            dietFilters: SharedDefaults.dietFilters(),
            allergenAvoids: SharedDefaults.allergenAvoids()
        )

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
            isEmptyBoard: choice.isEmptyBoard,
            filterHint: filterHint
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
                .anteatsWidgetContent()
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("Today's Menu")
        .description("One hall’s meal — four dishes, hearts, Eat Filters. Pick a hall or auto.")
        .supportedFamilies([.systemMedium])
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
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.favoritesToday)
        return .result(dialog: "Eat Filters cleared")
    }
}

struct TodaysMenuView: View {
    let entry: TodaysMenuEntry

    private let dishLimit = 4

    var body: some View {
        homeScreenMenu
            .containerBackground(for: .widget) {
                WidgetChrome.canvas
            }
    }

    private var homeScreenMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetKicker(title: "TODAY", trailing: headerTrailing)

            Text(shortHallName(entry.hallName))
                .font(WidgetChrome.hero(18))
                .foregroundStyle(WidgetChrome.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .unredacted()

            if let hint = entry.filterHint, !entry.filtersEmptiedMenu {
                Text(hint)
                    .font(WidgetChrome.meta(12))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            let dishes = Array(entry.dishes.prefix(dishLimit))
            if dishes.isEmpty {
                Spacer(minLength: 0)
                if entry.filtersEmptiedMenu {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nothing matches your Eat Filters.")
                            .font(WidgetChrome.row(15))
                            .foregroundStyle(WidgetChrome.ink)
                        if let hint = entry.filterHint {
                            Text(hint)
                                .font(WidgetChrome.meta(13))
                                .foregroundStyle(WidgetChrome.accent)
                                .lineLimit(1)
                        }
                        Button(intent: ClearEatFiltersIntent()) {
                            Text("Clear filters")
                                .font(WidgetChrome.meta(13))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(WidgetChrome.accent, in: Capsule())
                                .foregroundStyle(Color.black)
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
                    .font(WidgetChrome.row(15))
                    .foregroundStyle(WidgetChrome.muted)
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(dishes.enumerated()), id: \.offset) { index, dish in
                        if index > 0 {
                            WidgetHairline()
                        }
                        Link(destination: entry.dishDeepLinkURL(dish)) {
                            HStack(spacing: 8) {
                                if entry.favorited.contains(dish) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(WidgetChrome.accent)
                                }
                                Text(dish)
                                    .font(WidgetChrome.row(15))
                                    .foregroundStyle(WidgetChrome.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(WidgetChrome.padding)
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

    private var headerTrailing: String? {
        if entry.awaitingMoreMeals {
            return TodaysMenuPeriodChrome.awaitingCaptionCompact
        }
        if !entry.period.isEmpty {
            if let end = entry.periodEndsAt, end > Date() {
                return "\(entry.period)  \(WidgetCountdownCopy.clock(at: end))"
            }
            if let open = entry.periodOpensAt, open > Date() {
                return "\(entry.period)  \(WidgetCountdownCopy.clock(at: open))"
            }
            return entry.period
        }
        return nil
    }

    private func shortHallName(_ name: String) -> String {
        name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
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

// MARK: - Favorites Today (hearted dishes on a live board)

struct FavoritesTodayEntry: TimelineEntry {
    let date: Date
    let hasFavorites: Bool
    let hallName: String?
    let hallID: String?
    let period: String?
    let dishes: [String]
    let filterHint: String?
    let deepLinkPeriod: String?
    let deepLinkDate: String?
    let reloadBoundaries: [Date]

    var deepLinkURL: URL {
        AnteatsDeepLink.eat(
            hall: hallID,
            period: deepLinkPeriod ?? period,
            date: deepLinkDate
        ).url
    }

    func dishDeepLinkURL(_ dish: String) -> URL {
        AnteatsDeepLink.eat(
            hall: hallID,
            period: deepLinkPeriod ?? period,
            dish: dish,
            date: deepLinkDate
        ).url
    }
}

struct FavoritesTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesTodayEntry {
        FavoritesTodayEntry(
            date: .now,
            hasFavorites: true,
            hallName: "The Anteatery",
            hallID: "anteatery",
            period: "Lunch",
            dishes: ["Crispy Okra", "Farro Salad"],
            filterHint: nil,
            deepLinkPeriod: "Lunch",
            deepLinkDate: nil,
            reloadBoundaries: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesTodayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesTodayEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            let reload = WidgetRefreshMath.nextReload(
                now: .now,
                boundaries: entry.reloadBoundaries,
                maxInterval: 30 * 60
            )
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> FavoritesTodayEntry {
        let favorites = SharedDefaults.favoriteDishNames()
        let filterHint = EatFilterHint.label(
            dietFilters: SharedDefaults.dietFilters(),
            allergenAvoids: SharedDefaults.allergenAvoids()
        )
        // Cache-first multi-hall scan — App Group boards from Eat open; network
        // only fills gaps so Favorites isn't stuck on Auto hall alone.
        let locations = await WidgetSnapshotPaint.diningLocations()
        let nowMinutes = UCITime.nowMinutes()
        let reloadBoundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes
        )

        guard !favorites.isEmpty else {
            return FavoritesTodayEntry(
                date: .now,
                hasFavorites: false,
                hallName: nil,
                hallID: nil,
                period: nil,
                dishes: [],
                filterHint: filterHint,
                deepLinkPeriod: nil,
                deepLinkDate: nil,
                reloadBoundaries: reloadBoundaries
            )
        }

        let liveHalls = locations.filter { !$0.isComingSoon }
        guard !liveHalls.isEmpty else {
            return FavoritesTodayEntry(
                date: .now,
                hasFavorites: true,
                hallName: nil,
                hallID: nil,
                period: nil,
                dishes: [],
                filterHint: filterHint,
                deepLinkPeriod: nil,
                deepLinkDate: nil,
                reloadBoundaries: reloadBoundaries
            )
        }

        let service = WidgetSnapshotPaint.diningService()
        let todayISO = UCITime.todayISO()
        var boards: [FavoritesOnMenuPick.Board] = []
        for hall in liveHalls {
            let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
            let choice = TodaysMenuPeriodPick.choose(
                timedPeriods: timed,
                availablePeriods: hall.availablePeriods,
                nowMinutes: nowMinutes
            )
            let pill = choice.period
            guard !pill.isEmpty else { continue }

            let cachedMenu = WidgetSnapshotStore.loadDiningMenu(
                hall: hall.id,
                period: pill,
                dateISO: todayISO
            )
            let menu: DiningMenu?
            if let cachedMenu, !cachedMenu.stations.isEmpty {
                menu = cachedMenu
            } else if let networkedMenu = try? await service.menu(for: hall.id, period: pill) {
                WidgetSnapshotStore.saveDiningMenu(networkedMenu)
                menu = networkedMenu
            } else {
                menu = cachedMenu
            }
            guard let menu, !menu.stations.isEmpty else { continue }

            let displayPeriod = MealPeriodDisplay.label(
                live: choice.livePeriodName,
                pill: pill
            )
            boards.append(
                FavoritesOnMenuPick.Board(
                    hallID: hall.id,
                    hallName: hall.name,
                    period: displayPeriod,
                    stations: menu.stations
                )
            )
        }

        if let pick = FavoritesOnMenuPick.best(favorites: favorites, boards: boards) {
            let deepLinkPeriod = MealPeriodPill.canonical(pick.period)
            return FavoritesTodayEntry(
                date: .now,
                hasFavorites: true,
                hallName: pick.hallName,
                hallID: pick.hallID,
                period: pick.period,
                dishes: pick.rows.map(\.dishName),
                filterHint: filterHint,
                deepLinkPeriod: deepLinkPeriod,
                deepLinkDate: nil,
                reloadBoundaries: reloadBoundaries
            )
        }

        // No hearts on any live board — keep Auto hall chrome for empty copy.
        let auto = TodaysMenuHallPick.auto(from: liveHalls, nowMinutes: nowMinutes)
        return FavoritesTodayEntry(
            date: .now,
            hasFavorites: true,
            hallName: auto?.name,
            hallID: auto?.id,
            period: nil,
            dishes: [],
            filterHint: filterHint,
            deepLinkPeriod: nil,
            deepLinkDate: nil,
            reloadBoundaries: reloadBoundaries
        )
    }
}

struct FavoritesTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetTimelineKinds.favoritesToday,
            provider: FavoritesTodayProvider()
        ) { entry in
            FavoritesTodayView(entry: entry)
                .anteatsWidgetContent()
                .containerBackground(for: .widget) {
                    WidgetChrome.canvas
                }
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("Favorites Today")
        .description("The hearted dish on today’s board — open Anteats once if empty.")
        .supportedFamilies([.systemSmall])
    }
}

struct FavoritesTodayView: View {
    let entry: FavoritesTodayEntry

    private let dishLimit = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetKicker(title: "FAVES", trailing: entry.period)

            if let dish = entry.dishes.first {
                Spacer(minLength: 0)
                Text(dish)
                    .font(WidgetChrome.hero(20))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .unredacted()
                if let hall = entry.hallName {
                    Text(hall.hasPrefix("The ") ? String(hall.dropFirst(4)) : hall)
                        .font(WidgetChrome.row(15))
                        .foregroundStyle(WidgetChrome.accent)
                        .lineLimit(1)
                        .unredacted()
                }
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                Text(FavoritesOnMenuPick.emptyTitle(hasFavorites: entry.hasFavorites))
                    .font(WidgetChrome.row(16))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(2)
                Text(FavoritesOnMenuPick.emptyMessage(hasFavorites: entry.hasFavorites))
                    .font(WidgetChrome.meta(13))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
        }
        .padding(WidgetChrome.padding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(favoritesAccessibilityLabel)
    }

    private var favoritesAccessibilityLabel: String {
        if entry.dishes.isEmpty {
            return FavoritesOnMenuPick.emptyTitle(hasFavorites: entry.hasFavorites)
        }
        let hall = entry.hallName ?? "Dining"
        let period = entry.period ?? "meal"
        let listed = entry.dishes.prefix(dishLimit).joined(separator: ", ")
        return "Favorites for \(period) at \(hall): \(listed)"
    }
}

#Preview(as: .systemSmall) {
    FavoritesTodayWidget()
} timeline: {
    FavoritesTodayEntry(
        date: .now,
        hasFavorites: true,
        hallName: "The Anteatery",
        hallID: "anteatery",
        period: "Lunch",
        dishes: ["Crispy Okra", "Farro Salad", "Teriyaki"],
        filterHint: "Vegan",
        deepLinkPeriod: "Lunch",
        deepLinkDate: nil,
        reloadBoundaries: []
    )
}

// MARK: - Campus open now

struct CampusOpenEntry: TimelineEntry {
    let date: Date
    let openPlaces: [(id: String, name: String, hours: String)]
    let totalOpen: Int
    /// When nothing is open — soonest reopen for empty-state copy / deep link.
    let nextOpen: CampusNextOpenHint.Hint?
    /// No places at all (cache + network empty) — honest refresh copy.
    let needsAppRefresh: Bool

    init(
        date: Date,
        openPlaces: [(id: String, name: String, hours: String)],
        totalOpen: Int,
        nextOpen: CampusNextOpenHint.Hint? = nil,
        needsAppRefresh: Bool = false
    ) {
        self.date = date
        self.openPlaces = openPlaces
        self.totalOpen = totalOpen
        self.nextOpen = nextOpen
        self.needsAppRefresh = needsAppRefresh
    }
}

struct CampusOpenProvider: TimelineProvider {
    func placeholder(in context: Context) -> CampusOpenEntry {
        let places = WidgetSnapshotStore.loadCampusPlacesIfCurrentDay() ?? []
        switch WidgetPlaceholderHonesty.source(
            hasSnapshot: !places.isEmpty,
            isPreview: context.isPreview
        ) {
        case .snapshot:
            return entry(from: places)
        case .gallery:
            return Self.gallerySample()
        case .needsRefresh:
            return CampusOpenEntry(
                date: .now,
                openPlaces: [],
                totalOpen: 0,
                needsAppRefresh: true
            )
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (CampusOpenEntry) -> Void) {
        if context.isPreview {
            let places = WidgetSnapshotStore.loadCampusPlacesIfCurrentDay() ?? []
            if !places.isEmpty {
                completion(entry(from: places))
            } else {
                completion(Self.gallerySample())
            }
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CampusOpenEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let places = await loadPlaces()
            let entry = entry(from: places)
            let reload = CampusOpenReload.nextReload(now: .now, places: places)
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> CampusOpenEntry {
        entry(from: await loadPlaces())
    }

    private static func gallerySample() -> CampusOpenEntry {
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

    private func loadPlaces() async -> [CampusPlace] {
        await WidgetSnapshotPaint.campusPlaces()
    }

    private func entry(from places: [CampusPlace]) -> CampusOpenEntry {
        guard !places.isEmpty else {
            return CampusOpenEntry(
                date: .now,
                openPlaces: [],
                totalOpen: 0,
                needsAppRefresh: true
            )
        }
        let favoriteIDs = Set(SharedDefaults.favoriteCampusPlaceIDs())
        let open = CampusPlaceSort.sortOpenForWidget(
            places: places,
            favoriteIDs: favoriteIDs
        )
        let rows = open.prefix(6).map { place -> (id: String, name: String, hours: String) in
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
                .anteatsWidgetContent()
                .widgetURL(AnteatsWidgetURL.campus)
        }
        .configurationDisplayName("Campus Open Now")
        .description("What’s open on campus — one place small, three on medium.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
        ])
    }
}

struct CampusOpenView: View {
    let entry: CampusOpenEntry
    @Environment(\.widgetFamily) private var family

    private var rowLimit: Int { family == .systemSmall ? 1 : 3 }

    var body: some View {
        homeScreen
            .containerBackground(for: .widget) {
                WidgetChrome.canvas
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

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetKicker(
                title: "CAMPUS",
                trailing: entry.totalOpen == 0 ? nil : "\(entry.totalOpen) open"
            )

            if entry.needsAppRefresh {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(16))
                    .foregroundStyle(WidgetChrome.ink)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(13))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else if entry.openPlaces.isEmpty {
                Spacer(minLength: 0)
                if let hint = entry.nextOpen {
                    Link(destination: AnteatsDeepLink.campus(placeID: hint.placeID).url) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nothing’s open right now.")
                                .font(WidgetChrome.row(16))
                                .foregroundStyle(WidgetChrome.ink)
                            Text(hint.line)
                                .font(WidgetChrome.row(15))
                                .foregroundStyle(WidgetChrome.accent)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text("Nothing’s open right now.")
                        .font(WidgetChrome.row(16))
                        .foregroundStyle(WidgetChrome.muted)
                }
                Spacer(minLength: 0)
            } else if family == .systemSmall {
                let place = entry.openPlaces[0]
                Spacer(minLength: 0)
                Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(WidgetChrome.hero(20))
                            .foregroundStyle(WidgetChrome.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(place.hours)
                            .font(WidgetChrome.hero(22))
                            .foregroundStyle(WidgetChrome.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.openPlaces.prefix(rowLimit).enumerated()), id: \.element.id) { index, place in
                        if index > 0 {
                            WidgetHairline()
                        }
                        Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(place.name)
                                    .font(WidgetChrome.row(16))
                                    .foregroundStyle(WidgetChrome.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                Spacer(minLength: 8)
                                Text(place.hours)
                                    .font(WidgetChrome.row(15))
                                    .foregroundStyle(WidgetChrome.accent)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(WidgetChrome.padding)
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
    /// True when we have no Waitz snapshot — honest refresh copy, not a fake %.
    let needsAppRefresh: Bool

    init(
        date: Date,
        name: String,
        percent: Int?,
        facilityID: Int? = nil,
        updatedAt: Date? = nil,
        reopenMinutes: Int? = nil,
        needsAppRefresh: Bool = false
    ) {
        self.date = date
        self.name = name
        self.percent = percent
        self.facilityID = facilityID
        self.updatedAt = updatedAt
        self.reopenMinutes = reopenMinutes
        self.needsAppRefresh = needsAppRefresh
    }
}

struct QuietestLibraryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuietestLibraryEntry {
        let facilities = WidgetSnapshotStore.loadBusynessPlacesIfPresent()
        switch WidgetPlaceholderHonesty.source(
            hasSnapshot: facilities != nil,
            isPreview: context.isPreview
        ) {
        case .snapshot:
            return Self.entry(from: facilities ?? [])
        case .gallery:
            return QuietestLibraryEntry(
                date: .now,
                name: "Langson · 4th Floor",
                percent: WidgetPlaceholderHonesty.galleryLibraryPercent
            )
        case .needsRefresh:
            return QuietestLibraryEntry(
                date: .now,
                name: WidgetLoadEmptyCopy.title,
                percent: nil,
                needsAppRefresh: true
            )
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (QuietestLibraryEntry) -> Void) {
        if context.isPreview {
            if let facilities = WidgetSnapshotStore.loadBusynessPlacesIfPresent() {
                completion(Self.entry(from: facilities))
            } else {
                completion(
                    QuietestLibraryEntry(
                        date: .now,
                        name: "Langson · 4th Floor",
                        percent: WidgetPlaceholderHonesty.galleryLibraryPercent
                    )
                )
            }
            return
        }
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuietestLibraryEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            let facilities = WidgetSnapshotStore.loadBusynessPlaces() ?? []
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
        Self.entry(from: await WidgetSnapshotPaint.busynessPlaces())
    }

    private static func entry(from facilities: [BusynessPoint]) -> QuietestLibraryEntry {
        if facilities.isEmpty {
            return QuietestLibraryEntry(
                date: .now,
                name: WidgetLoadEmptyCopy.title,
                percent: nil,
                needsAppRefresh: true
            )
        }
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
                .anteatsWidgetContent()
                .widgetURL(AnteatsDeepLink.study(facilityID: entry.facilityID).url)
        }
        .configurationDisplayName("Quietest Library")
        .description("The quietest library floor — live Waitz percent, or an honest empty.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuietestLibraryView: View {
    let entry: QuietestLibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetKicker(title: "STUDY")

            if entry.needsAppRefresh {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(16))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(3)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(13))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
                Text(entry.name)
                    .font(WidgetChrome.row(16))
                    .foregroundStyle(WidgetChrome.ink.opacity(0.72))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .unredacted()

                if let percent = entry.percent {
                    Spacer(minLength: 0)
                    Text("\(percent)")
                        .font(WidgetChrome.hero(36))
                        .monospacedDigit()
                        .foregroundStyle(WidgetChrome.accent)
                        .unredacted()
                    Text("% full")
                        .font(WidgetChrome.meta(13))
                        .foregroundStyle(WidgetChrome.muted)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    Text(
                        StudyIdleCopy.quietestClosedDetail(reopenMinutes: entry.reopenMinutes)
                    )
                    .font(WidgetChrome.row(15))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(WidgetChrome.padding)
        .accessibilityLabel(
            entry.needsAppRefresh
                ? WidgetLoadEmptyCopy.title
                : quietestAccessibilityLabel(includeQuietestQualifier: false)
        )
        .containerBackground(for: .widget) {
            WidgetChrome.canvas
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

#Preview(as: .systemSmall) {
    QuietestLibraryWidget()
} timeline: {
    QuietestLibraryEntry(date: .now, name: "Langson · 4th Floor", percent: 8)
}
