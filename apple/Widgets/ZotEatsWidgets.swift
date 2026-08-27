import WidgetKit
import SwiftUI
import UIKit
import ActivityKit
import AppIntents
import ZotEatsKit

// Home-screen + lock-screen widgets for Anteats.
// Focused gallery (no Gym/ARC): Dining Status, Today's Menu, Favorites Today,
// Campus Open Now, Quietest Library + Meal Live Activity.
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
        CampusStudyWidget()
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

/// Home Screen widget chrome — parchment canvas, nested cards, one grotesque
/// (Instrument Sans), gold accent. No expanded-black shout.
/// Colors follow the Home Screen appearance so Dark Mode actually flips.
private enum WidgetChrome {
    static let open = Color(red: 1 / 255, green: 168 / 255, blue: 88 / 255)

    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28 / 255, green: 28 / 255, blue: 26 / 255, alpha: 1)
            : UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 1)
    })

    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 40 / 255, green: 40 / 255, blue: 37 / 255, alpha: 1)
            : UIColor(red: 241 / 255, green: 240 / 255, blue: 232 / 255, alpha: 1)
    })

    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 1)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 1)
    })

    static let muted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 0.58)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 0.52)
    })

    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 0.08)
    })

    /// Gold on parchment; brighter gold on charcoal so it still reads in Dark Mode.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 210 / 255, blue: 0 / 255, alpha: 1)
            : UIColor(red: 176 / 255, green: 118 / 255, blue: 0 / 255, alpha: 1)
    })

    static func display(_ size: CGFloat) -> Font {
        .custom("Instrument Sans", size: size).weight(.medium)
    }

    static func kicker(_ size: CGFloat) -> Font {
        .custom("Instrument Sans", size: size).weight(.medium)
    }

    static func row(_ size: CGFloat) -> Font {
        .custom("Instrument Sans", size: size).weight(.medium)
    }

    static func meta(_ size: CGFloat) -> Font {
        .custom("Instrument Sans", size: size)
    }
}

private struct WidgetKicker: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(WidgetChrome.kicker(11))
                .tracking(0.8)
                .foregroundStyle(WidgetChrome.accent)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(WidgetChrome.display(13))
                    .foregroundStyle(WidgetChrome.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct WidgetInsetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                WidgetChrome.card,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WidgetChrome.hairline, lineWidth: 1)
            )
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
        "Hall clocks. Medium adds today’s dishes; Large adds campus and study. Hide Coming Soon if you want."
    )

    @Parameter(title: "Show Coming Soon halls", default: true)
    var showComingSoon: Bool
}

struct DiningStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DiningStatusEntry {
        placeholder(for: DiningHallsConfigurationIntent(), in: context)
    }

    func placeholder(for configuration: DiningHallsConfigurationIntent, in context: Context) -> DiningStatusEntry {
        _ = configuration
        return DiningStatusEntry(
            date: .now,
            halls: [
                .init(id: "anteatery", name: "The Anteatery", statusText: "Lunch · 11:30 AM", isOpen: false, occupancy: nil, countdownEnd: nil, countdownKind: nil),
                .init(id: "brandywine", name: "Brandywine", statusText: "Breakfast · 11:00 AM", isOpen: true, occupancy: 65, countdownEnd: .now.addingTimeInterval(5400), countdownKind: .closes),
                .init(id: "oasis", name: "The Oasis", statusText: "Coming Soon", isOpen: false, occupancy: nil, countdownEnd: nil, countdownKind: nil, isComingSoon: true),
            ],
            quietest: .open(name: "Langson · 4th", percent: 8, facilityID: 1, updatedAt: .now),
            boardHallName: "Brandywine",
            boardHallID: "brandywine",
            boardDishes: ["Crispy Okra", "Farro Salad", "BBQ Pork"],
            campusOpen: [
                .init(id: "starbucks-at-student-center", name: "Starbucks", hours: "until 4 PM"),
            ],
            campusOpenCount: 6
        )
    }

    func snapshot(for configuration: DiningHallsConfigurationIntent, in context: Context) async -> DiningStatusEntry {
        if context.isPreview { return placeholder(for: configuration, in: context) }
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
        async let locationsTask = WidgetSnapshotPaint.diningLocations()
        async let waitzTask = WidgetSnapshotPaint.busynessPlaces()
        let locations = await locationsTask
        let waitzPlaces = await waitzTask

        let nowMinutes = UCITime.nowMinutes()
        guard !locations.isEmpty else {
            return (
                DiningStatusEntry(date: .now, halls: [], needsAppRefresh: true),
                [],
                [],
                []
            )
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
        if !waitzPlaces.isEmpty {
            quietest = QuietestLibraryGlance.diningStatusTip(from: waitzPlaces)
            libraryReopenMinutes = QuietestLibraryReload.reopenMinutes(from: waitzPlaces)
            libraryCloseMinutes = QuietestLibraryReload.closeMinutes(from: waitzPlaces)
        } else {
            quietest = nil
            libraryReopenMinutes = []
            libraryCloseMinutes = []
        }

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

        let campusPlaces = WidgetSnapshotStore.loadCampusPlaces() ?? []
        let campus = WidgetGlanceExtras.campusRows(
            places: campusPlaces,
            favoriteIDs: Set(SharedDefaults.favoriteCampusPlaceIDs()),
            favoritesOnly: false,
            limit: 3
        )

        return (
            DiningStatusEntry(
                date: .now,
                halls: halls,
                quietest: quietest,
                boardHallName: boardHallName,
                boardHallID: boardHallID,
                boardDishes: boardDishes,
                campusOpen: campus.rows,
                campusOpenCount: campus.totalOpen
            ),
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
        AppIntentConfiguration(
            kind: WidgetTimelineKinds.diningStatus,
            intent: DiningHallsConfigurationIntent.self,
            provider: DiningStatusProvider()
        ) { entry in
            DiningStatusView(entry: entry)
                .anteatsWidgetContent()
                .containerBackground(for: .widget) {
                    WidgetChrome.canvas
                }
                .widgetURL(AnteatsWidgetURL.eat)
        }
        .configurationDisplayName("Dining Halls")
        .description("Hall clocks. Medium adds today’s dishes; Large adds campus and study.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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

    private var isCompact: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    private var visibleHalls: ArraySlice<DiningStatusEntry.HallStatus> {
        entry.halls.prefix(DiningStatusLayout.hallLimit(isCompact: isCompact, isLarge: isLarge))
    }
    private var hallCount: Int { visibleHalls.count }

    var body: some View {
        let spacing = DiningStatusLayout.rowSpacing(isCompact: isCompact, hallCount: hallCount)
        VStack(alignment: .leading, spacing: spacing) {
            WidgetKicker(title: "EAT")

            if entry.needsAppRefresh || entry.halls.isEmpty {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(14))
                    .foregroundStyle(WidgetChrome.ink)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(12))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
                WidgetInsetCard {
                    VStack(alignment: .leading, spacing: DiningStatusLayout.hallRowSpacing(isCompact: isCompact, hallCount: hallCount)) {
                        ForEach(Array(visibleHalls), id: \.id) { hall in
                            Link(destination: AnteatsDeepLink.eat(
                                hall: hall.id,
                                period: hall.deepLinkPeriod,
                                date: hall.deepLinkDate
                            ).url) {
                                hallRow(hall)
                            }
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
        .overlay(alignment: .bottomTrailing) {
            if !isCompact && !isLarge {
                Text("EAT")
                    .font(WidgetChrome.display(44))
                    .foregroundStyle(WidgetChrome.ink.opacity(0.06))
                    .padding(.trailing, 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var boardStrip: some View {
        if !entry.boardDishes.isEmpty {
            let dishes = Array(entry.boardDishes.prefix(DiningStatusLayout.boardDishLimit(isLarge: isLarge)))
            WidgetInsetCard {
                VStack(alignment: .leading, spacing: 5) {
                    Text((entry.boardHallName ?? "Board").uppercased())
                        .font(WidgetChrome.kicker(10))
                        .tracking(0.8)
                        .foregroundStyle(WidgetChrome.accent)
                    ForEach(dishes, id: \.self) { dish in
                        Link(destination: AnteatsDeepLink.eat(
                            hall: entry.boardHallID,
                            dish: dish
                        ).url) {
                            Text(dish)
                                .font(WidgetChrome.row(11))
                                .foregroundStyle(WidgetChrome.ink)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var campusStrip: some View {
        if DiningStatusLayout.showsCampusStrip(isLarge: isLarge), !entry.campusOpen.isEmpty {
            WidgetInsetCard {
                VStack(alignment: .leading, spacing: 5) {
                    WidgetKicker(
                        title: "CAMPUS",
                        trailing: entry.campusOpenCount == 0 ? nil : "\(entry.campusOpenCount) OPEN"
                    )
                    ForEach(Array(entry.campusOpen.prefix(DiningStatusLayout.campusRowLimit(isLarge: true))), id: \.id) { place in
                        Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                            HStack {
                                Text(place.name.uppercased())
                                    .font(WidgetChrome.row(11))
                                    .foregroundStyle(WidgetChrome.ink)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(place.hours.uppercased())
                                    .font(WidgetChrome.meta(10))
                                    .foregroundStyle(WidgetChrome.accent)
                                    .lineLimit(1)
                            }
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
            WidgetInsetCard {
                switch quietest {
                case .open(let name, let percent, let facilityID, _):
                    Link(destination: AnteatsDeepLink.study(facilityID: facilityID).url) {
                        HStack {
                            Text("STUDY")
                                .font(WidgetChrome.kicker(10))
                                .tracking(0.8)
                                .foregroundStyle(WidgetChrome.accent)
                            Spacer(minLength: 4)
                            Text("\(name.uppercased()) · \(percent)%")
                                .font(WidgetChrome.row(11))
                                .foregroundStyle(WidgetChrome.ink)
                                .lineLimit(1)
                        }
                    }
                case .librariesClosed:
                    Text("LIBRARIES CLOSED")
                        .font(WidgetChrome.row(11))
                        .foregroundStyle(WidgetChrome.muted)
                }
            }
        }
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        let nameSize = DiningStatusLayout.nameFontSize(isCompact: isCompact, hallCount: hallCount)
        let clockSize = DiningStatusLayout.statusFontSize(isCompact: isCompact, hallCount: hallCount)
        let raw = isCompact ? DiningStatusWidgetLine.tighten(hall.statusText) : hall.statusText
        let split = DiningStatusWidgetLine.splitMealAndClock(raw)
        let subtitle: String = {
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
            VStack(alignment: .leading, spacing: 1) {
                Text(shortName(hall.name).uppercased())
                    .font(WidgetChrome.row(nameSize))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle.uppercased())
                    .font(WidgetChrome.meta(isCompact ? 9 : 10))
                    .tracking(0.5)
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(1)
                    .opacity(subtitle.isEmpty ? 0 : 1)
            }
            Text(trailing.uppercased())
                .font(WidgetChrome.display(clockSize))
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

#Preview(as: .systemMedium) {
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

/// Paint App Group snapshots immediately; refresh the suite in the background
/// so remaining glances match Dining Status (cache first, network second).
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
        .description("Today's meal at a glance — Eat Filters hint + favorites. Pick a hall or auto.")
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
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.favoritesToday)
        return .result(dialog: "Eat Filters cleared")
    }
}

struct TodaysMenuView: View {
    let entry: TodaysMenuEntry
    @Environment(\.widgetFamily) private var family

    private var dishLimit: Int {
        switch family {
        case .systemLarge: return 10
        case .accessoryRectangular: return 2
        default: return 4
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                lunchGlance
            default:
                homeScreenMenu
            }
        }
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryRectangular:
                Color.clear
            default:
                WidgetChrome.canvas
            }
        }
    }

    /// Compact Lock Screen / StandBy “what’s for lunch” glance.
    private var lunchGlance: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 11, weight: .semibold))
                Text(glanceTitle)
                    .font(WidgetChrome.row(13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if let first = Array(entry.dishes.prefix(dishLimit)).first {
                Link(destination: entry.dishDeepLinkURL(first)) {
                    Text(first)
                        .font(WidgetChrome.meta(12))
                        .opacity(0.85)
                        .lineLimit(1)
                }
                if entry.dishes.count > 1 {
                    let second = entry.dishes[1]
                    Link(destination: entry.dishDeepLinkURL(second)) {
                        Text(second)
                            .font(WidgetChrome.meta(12))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
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
                    .font(WidgetChrome.meta(12))
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
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(
                title: shortHallName(entry.hallName).uppercased(),
                trailing: headerTrailing
            )

            if let hint = entry.filterHint, !entry.filtersEmptiedMenu {
                Text(hint.uppercased())
                    .font(WidgetChrome.meta(10))
                    .tracking(0.6)
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
                            .font(WidgetChrome.meta(12))
                            .foregroundStyle(WidgetChrome.muted)
                        if let hint = entry.filterHint {
                            Text(hint)
                                .font(WidgetChrome.row(11))
                                .foregroundStyle(WidgetChrome.accent)
                                .lineLimit(1)
                        }
                        Button(intent: ClearEatFiltersIntent()) {
                            Text("Clear filters")
                                .font(WidgetChrome.meta(12))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
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
                    .font(WidgetChrome.meta(12))
                    .foregroundStyle(WidgetChrome.muted)
                }
                Spacer(minLength: 0)
            } else {
                WidgetInsetCard {
                    VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 6) {
                        ForEach(dishes, id: \.self) { dish in
                            Link(destination: entry.dishDeepLinkURL(dish)) {
                                HStack(spacing: 8) {
                                    if entry.favorited.contains(dish) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(WidgetChrome.accent)
                                    } else {
                                        Circle()
                                            .fill(WidgetChrome.accent)
                                            .frame(width: 4, height: 4)
                                    }
                                    Text(dish)
                                        .font(WidgetChrome.row(family == .systemLarge ? 13 : 12))
                                        .foregroundStyle(WidgetChrome.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                        if entry.dishes.count > dishLimit {
                            Text("+\(entry.dishes.count - dishLimit) MORE")
                                .font(WidgetChrome.kicker(10))
                                .tracking(0.8)
                                .foregroundStyle(WidgetChrome.muted)
                                .padding(.top, 2)
                        }
                    }
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

    private var headerTrailing: String? {
        if entry.awaitingMoreMeals {
            return TodaysMenuPeriodChrome.awaitingCaptionCompact.uppercased()
        }
        if !entry.period.isEmpty {
            if let end = entry.periodEndsAt, end > Date() {
                return "\(entry.period.uppercased())  \(WidgetCountdownCopy.clock(at: end))"
            }
            if let open = entry.periodOpensAt, open > Date() {
                return "\(entry.period.uppercased())  \(WidgetCountdownCopy.clock(at: open))"
            }
            return entry.period.uppercased()
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
        await withTaskGroup(of: FavoritesOnMenuPick.Board?.self) { group in
            for hall in liveHalls {
                let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
                let choice = TodaysMenuPeriodPick.choose(
                    timedPeriods: timed,
                    availablePeriods: hall.availablePeriods,
                    nowMinutes: nowMinutes
                )
                let pill = choice.period
                guard !pill.isEmpty else { continue }
                let hallID = hall.id
                let hallName = hall.name
                let livePeriodName = choice.livePeriodName
                group.addTask {
                    let cachedMenu = WidgetSnapshotStore.loadDiningMenu(
                        hall: hallID,
                        period: pill,
                        dateISO: todayISO
                    )
                    let menu: DiningMenu?
                    if let cachedMenu, !cachedMenu.stations.isEmpty {
                        menu = cachedMenu
                    } else if let networkedMenu = try? await service.menu(for: hallID, period: pill) {
                        WidgetSnapshotStore.saveDiningMenu(networkedMenu)
                        menu = networkedMenu
                    } else {
                        menu = cachedMenu
                    }
                    guard let menu, !menu.stations.isEmpty else { return nil }
                    let displayPeriod = MealPeriodDisplay.label(
                        live: livePeriodName,
                        pill: pill
                    )
                    return FavoritesOnMenuPick.Board(
                        hallID: hallID,
                        hallName: hallName,
                        period: displayPeriod,
                        stations: menu.stations
                    )
                }
            }
            for await board in group {
                if let board { boards.append(board) }
            }
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
        .description("Hearted dishes on today's board — open Anteats once if empty.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FavoritesTodayView: View {
    let entry: FavoritesTodayEntry
    @Environment(\.widgetFamily) private var family

    private var dishLimit: Int { family == .systemSmall ? 2 : 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(
                title: "FAVORITES",
                trailing: entry.period?.uppercased()
            )

            if let hall = entry.hallName, !entry.dishes.isEmpty {
                Text((hall.hasPrefix("The ") ? String(hall.dropFirst(4)) : hall).uppercased())
                    .font(WidgetChrome.meta(10))
                    .tracking(0.5)
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(1)
            }

            if let hint = entry.filterHint {
                Text(hint.uppercased())
                    .font(WidgetChrome.meta(10))
                    .tracking(0.5)
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(1)
            }

            if entry.dishes.isEmpty {
                Spacer(minLength: 0)
                Text(FavoritesOnMenuPick.emptyTitle(hasFavorites: entry.hasFavorites))
                    .font(WidgetChrome.row(13))
                    .foregroundStyle(WidgetChrome.ink)
                    .lineLimit(2)
                Text(FavoritesOnMenuPick.emptyMessage(hasFavorites: entry.hasFavorites))
                    .font(WidgetChrome.meta(11))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
                WidgetInsetCard {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(entry.dishes.prefix(dishLimit)), id: \.self) { dish in
                            Link(destination: entry.dishDeepLinkURL(dish)) {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(WidgetChrome.accent)
                                    Text(dish)
                                        .font(WidgetChrome.row(12))
                                        .foregroundStyle(WidgetChrome.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                        if entry.dishes.count > dishLimit {
                            Text("+\(entry.dishes.count - dishLimit) MORE")
                                .font(WidgetChrome.kicker(10))
                                .tracking(0.8)
                                .foregroundStyle(WidgetChrome.muted)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
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

#Preview(as: .systemMedium) {
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
            let places = await loadPlaces()
            let entry = entry(from: places)
            let reload = CampusOpenReload.nextReload(now: .now, places: places)
            deliver.value(Timeline(entries: [entry], policy: .after(reload)))
        }
    }

    private func fetchEntry() async -> CampusOpenEntry {
        entry(from: await loadPlaces())
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
                .containerBackground(for: .widget) {
                    WidgetChrome.canvas
                }
                .widgetURL(AnteatsWidgetURL.campus)
        }
        .configurationDisplayName("Campus Open Now")
        .description("Which cafés and food courts are open right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CampusOpenView: View {
    let entry: CampusOpenEntry
    @Environment(\.widgetFamily) private var family

    private var rowLimit: Int {
        switch family {
        case .systemLarge: return 6
        case .systemSmall: return 1
        default: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 8) {
            WidgetKicker(title: "CAMPUS", trailing: entry.totalOpen == 0 ? nil : "\(entry.totalOpen) OPEN")

            if entry.needsAppRefresh {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(13))
                    .foregroundStyle(WidgetChrome.ink)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(11))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else if entry.openPlaces.isEmpty {
                Spacer(minLength: 0)
                if let hint = entry.nextOpen {
                    Link(destination: AnteatsDeepLink.campus(placeID: hint.placeID).url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nothing's open right now.")
                                .font(WidgetChrome.meta(12))
                                .foregroundStyle(WidgetChrome.muted)
                            Text(hint.line)
                                .font(WidgetChrome.row(12))
                                .foregroundStyle(WidgetChrome.accent)
                                .lineLimit(2)
                        }
                    }
                } else {
                    Text("Nothing's open right now.")
                        .font(WidgetChrome.meta(12))
                        .foregroundStyle(WidgetChrome.muted)
                }
                Spacer(minLength: 0)
            } else if family == .systemSmall {
                if let first = entry.openPlaces.first {
                    WidgetInsetCard {
                        Link(destination: AnteatsDeepLink.campus(placeID: first.id).url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(first.name.uppercased())
                                    .font(WidgetChrome.row(13))
                                    .foregroundStyle(WidgetChrome.ink)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                Text(first.hours.uppercased())
                                    .font(WidgetChrome.display(16))
                                    .foregroundStyle(WidgetChrome.accent)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                if entry.totalOpen > 1 {
                    Text("+\(entry.totalOpen - 1) MORE OPEN")
                        .font(WidgetChrome.kicker(10))
                        .tracking(0.8)
                        .foregroundStyle(WidgetChrome.muted)
                }
                Spacer(minLength: 0)
            } else {
                WidgetInsetCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entry.openPlaces.prefix(rowLimit)), id: \.id) { place in
                            Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(WidgetChrome.open)
                                        .frame(width: 6, height: 6)
                                    Text(place.name.uppercased())
                                        .font(WidgetChrome.row(12))
                                        .foregroundStyle(WidgetChrome.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    Spacer(minLength: 4)
                                    Text(place.hours.uppercased())
                                        .font(WidgetChrome.display(12))
                                        .foregroundStyle(WidgetChrome.accent)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .layoutPriority(1)
                                }
                            }
                        }
                        if entry.totalOpen > rowLimit {
                            Text("+\(entry.totalOpen - rowLimit) MORE")
                                .font(WidgetChrome.kicker(10))
                                .tracking(0.8)
                                .foregroundStyle(WidgetChrome.muted)
                        }
                    }
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
                percent: nil
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
        .description("The quietest library floor right now — home screen or lock screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuietestLibraryView: View {
    let entry: QuietestLibraryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                if let percent = entry.percent {
                    Gauge(value: Double(percent), in: 0...100) {
                        Image(systemName: "books.vertical.fill")
                    } currentValueLabel: {
                        Text("\(percent)%")
                            .font(WidgetChrome.row(14))
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
                            .font(WidgetChrome.row(13))
                            .lineLimit(1)
                        Text(QuietestLibraryGlance.widgetRectangularDetail(
                            percent: entry.percent,
                            reopenMinutes: entry.reopenMinutes
                        ))
                            .font(WidgetChrome.meta(11))
                            .opacity(0.8)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(quietestAccessibilityLabel(includeQuietestQualifier: true))
            default:
                VStack(alignment: .leading, spacing: 8) {
                    WidgetKicker(title: "STUDY")

                    Text(entry.name.uppercased())
                        .font(WidgetChrome.row(14))
                        .foregroundStyle(WidgetChrome.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)

                    if let percent = entry.percent {
                        Text("\(percent)")
                            .font(WidgetChrome.display(34))
                            .monospacedDigit()
                            .foregroundStyle(WidgetChrome.accent)
                        Text("% FULL · QUIETEST NOW")
                            .font(WidgetChrome.kicker(10))
                            .tracking(0.6)
                            .foregroundStyle(WidgetChrome.muted)
                    } else {
                        Text(
                            StudyIdleCopy.quietestClosedDetail(reopenMinutes: entry.reopenMinutes)
                        )
                            .font(WidgetChrome.meta(12))
                            .foregroundStyle(WidgetChrome.muted)
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
                WidgetChrome.canvas
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

// MARK: - Campus + Study combo

struct CampusStudyConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Campus + Study"
    static let description: IntentDescription = IntentDescription(
        "Open campus spots plus the quietest library. Optionally only hearted cafés."
    )

    @Parameter(title: "Campus favorites only", default: false)
    var favoritesOnly: Bool
}

struct CampusStudyEntry: TimelineEntry {
    let date: Date
    let campusOpen: [WidgetGlanceExtras.CampusRow]
    let campusOpenCount: Int
    let nextOpen: CampusNextOpenHint.Hint?
    let needsAppRefresh: Bool
    let libraryName: String
    let libraryPercent: Int?
    let libraryFacilityID: Int?
    let libraryReopenMinutes: Int?
}

struct CampusStudyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CampusStudyEntry {
        placeholder(for: CampusStudyConfigurationIntent(), in: context)
    }

    func placeholder(for configuration: CampusStudyConfigurationIntent, in context: Context) -> CampusStudyEntry {
        _ = configuration
        return CampusStudyEntry(
            date: .now,
            campusOpen: [
                .init(id: "starbucks-at-student-center", name: "Starbucks", hours: "until 4 PM"),
                .init(id: "panda-express", name: "Panda Express", hours: "until 7 PM"),
            ],
            campusOpenCount: 6,
            nextOpen: nil,
            needsAppRefresh: false,
            libraryName: "Langson · 4th Floor",
            libraryPercent: 8,
            libraryFacilityID: 1,
            libraryReopenMinutes: nil
        )
    }

    func snapshot(for configuration: CampusStudyConfigurationIntent, in context: Context) async -> CampusStudyEntry {
        if context.isPreview { return placeholder(for: configuration, in: context) }
        return await fetchEntry(favoritesOnly: configuration.favoritesOnly)
    }

    func timeline(for configuration: CampusStudyConfigurationIntent, in context: Context) async -> Timeline<CampusStudyEntry> {
        let entry = await fetchEntry(favoritesOnly: configuration.favoritesOnly)
        let places = WidgetSnapshotStore.loadCampusPlaces() ?? []
        let facilities = WidgetSnapshotStore.loadBusynessPlaces() ?? []
        let campusReload = CampusOpenReload.nextReload(now: .now, places: places)
        let nowMinutes = UCITime.nowMinutes()
        let studyReload = QuietestLibraryReload.nextReload(
            now: .now,
            anyLibraryOpen: StudyBoundaryRefresh.anyLibraryOpen(
                from: facilities,
                nowMinutes: nowMinutes
            ),
            reopenMinutes: QuietestLibraryReload.reopenMinutes(from: facilities),
            closeMinutes: QuietestLibraryReload.closeMinutes(
                from: facilities,
                nowMinutes: nowMinutes
            )
        )
        let reload = min(campusReload, studyReload)
        return Timeline(entries: [entry], policy: .after(reload))
    }

    private func fetchEntry(favoritesOnly: Bool) async -> CampusStudyEntry {
        async let campusTask = WidgetSnapshotPaint.campusPlaces()
        async let waitzTask = WidgetSnapshotPaint.busynessPlaces()
        let campusPlaces = await campusTask
        let facilities = await waitzTask

        let campus = WidgetGlanceExtras.campusRows(
            places: campusPlaces,
            favoriteIDs: Set(SharedDefaults.favoriteCampusPlaceIDs()),
            favoritesOnly: favoritesOnly,
            limit: 4
        )
        let library = QuietestLibraryProvider.entryForCombo(from: facilities)
        let nextOpen = campus.totalOpen == 0 ? CampusNextOpenHint.best(from: campusPlaces) : nil
        return CampusStudyEntry(
            date: .now,
            campusOpen: campus.rows,
            campusOpenCount: campus.totalOpen,
            nextOpen: nextOpen,
            needsAppRefresh: campusPlaces.isEmpty && facilities.isEmpty,
            libraryName: library.name,
            libraryPercent: library.percent,
            libraryFacilityID: library.facilityID,
            libraryReopenMinutes: library.reopenMinutes
        )
    }
}

private extension QuietestLibraryProvider {
    static func entryForCombo(from facilities: [BusynessPoint]) -> QuietestLibraryEntry {
        entry(from: facilities)
    }
}

struct CampusStudyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetTimelineKinds.campusStudy,
            intent: CampusStudyConfigurationIntent.self,
            provider: CampusStudyProvider()
        ) { entry in
            CampusStudyView(entry: entry)
                .anteatsWidgetContent()
                .containerBackground(for: .widget) {
                    WidgetChrome.canvas
                }
                .widgetURL(AnteatsWidgetURL.campus)
        }
        .configurationDisplayName("Campus + Study")
        .description("Open cafés plus the quietest library. Optionally only hearted spots.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct CampusStudyView: View {
    let entry: CampusStudyEntry
    @Environment(\.widgetFamily) private var family

    private var campusLimit: Int { family == .systemLarge ? 4 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKicker(
                title: "CAMPUS + STUDY",
                trailing: entry.campusOpenCount == 0 ? nil : "\(entry.campusOpenCount) OPEN"
            )

            if entry.needsAppRefresh {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(WidgetChrome.row(13))
                    .foregroundStyle(WidgetChrome.ink)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(WidgetChrome.meta(11))
                    .foregroundStyle(WidgetChrome.muted)
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
                WidgetInsetCard {
                    VStack(alignment: .leading, spacing: 6) {
                        if entry.campusOpen.isEmpty {
                            if let hint = entry.nextOpen {
                                Text(hint.line)
                                    .font(WidgetChrome.row(12))
                                    .foregroundStyle(WidgetChrome.accent)
                                    .lineLimit(2)
                            } else {
                                Text("Nothing's open right now.")
                                    .font(WidgetChrome.meta(12))
                                    .foregroundStyle(WidgetChrome.muted)
                            }
                        } else {
                            ForEach(Array(entry.campusOpen.prefix(campusLimit)), id: \.id) { place in
                                Link(destination: AnteatsDeepLink.campus(placeID: place.id).url) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(WidgetChrome.open)
                                            .frame(width: 6, height: 6)
                                        Text(place.name.uppercased())
                                            .font(WidgetChrome.row(12))
                                            .foregroundStyle(WidgetChrome.ink)
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(place.hours.uppercased())
                                            .font(WidgetChrome.display(12))
                                            .foregroundStyle(WidgetChrome.accent)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                            }
                        }
                    }
                }

                WidgetInsetCard {
                    Link(destination: AnteatsDeepLink.study(facilityID: entry.libraryFacilityID).url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STUDY")
                                .font(WidgetChrome.kicker(10))
                                .tracking(0.8)
                                .foregroundStyle(WidgetChrome.accent)
                            Text(entry.libraryName.uppercased())
                                .font(WidgetChrome.row(12))
                                .foregroundStyle(WidgetChrome.ink)
                                .lineLimit(2)
                            if let percent = entry.libraryPercent {
                                Text("\(percent)% FULL · QUIETEST NOW")
                                    .font(WidgetChrome.meta(11))
                                    .foregroundStyle(WidgetChrome.muted)
                            } else {
                                Text(
                                    StudyIdleCopy.quietestClosedDetail(
                                        reopenMinutes: entry.libraryReopenMinutes
                                    )
                                )
                                .font(WidgetChrome.meta(11))
                                .foregroundStyle(WidgetChrome.muted)
                                .lineLimit(2)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    CampusStudyWidget()
} timeline: {
    CampusStudyEntry(
        date: .now,
        campusOpen: [
            .init(id: "starbucks-at-student-center", name: "Starbucks", hours: "until 4 PM"),
            .init(id: "panda-express", name: "Panda Express", hours: "until 7 PM"),
        ],
        campusOpenCount: 6,
        nextOpen: nil,
        needsAppRefresh: false,
        libraryName: "Langson · 4th Floor",
        libraryPercent: 8,
        libraryFacilityID: 1,
        libraryReopenMinutes: nil
    )
}
