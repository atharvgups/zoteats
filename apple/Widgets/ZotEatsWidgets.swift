import WidgetKit
import SwiftUI
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
                            hasEnded: ended,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(.system(size: 12))
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
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(activityGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                            .font(.system(size: 14, weight: .semibold))
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
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(activityGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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
                    Text(
                        MealCountdownChrome.compactTrailing(
                            period: context.attributes.period,
                            hasEnded: true,
                            postClosePeriod: context.state.postClosePeriod,
                            postCloseDate: context.state.postCloseDate
                        )
                    )
                        .font(.system(size: 12, weight: .bold))
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

    init(
        date: Date,
        halls: [HallStatus],
        quietest: QuietestLibraryGlance.DiningStatusTip? = nil,
        needsAppRefresh: Bool = false
    ) {
        self.date = date
        self.halls = halls
        self.quietest = quietest
        self.needsAppRefresh = needsAppRefresh
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
        // Cache-first: App Group snapshot from the main app paints real hall
        // names immediately; network refreshes when the extension budget allows.
        let cached = WidgetSnapshotStore.loadDiningLocations() ?? []
        let networked = await DiningService(http: HTTPClient(timeout: 8)).locations()
        let networkLooksLive = networked.contains {
            !$0.availablePeriods.isEmpty || $0.todayHours != nil || !$0.periods.isEmpty
        }
        let locations: [DiningLocation]
        if networkLooksLive {
            WidgetSnapshotStore.saveDiningLocations(networked)
            locations = networked
        } else if !cached.isEmpty {
            locations = cached
        } else {
            locations = networked
        }

        let nowMinutes = UCITime.nowMinutes()
        guard !locations.isEmpty else {
            return (
                DiningStatusEntry(date: .now, halls: [], needsAppRefresh: true),
                [],
                [],
                []
            )
        }

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
        let busynessCached = WidgetSnapshotStore.loadBusynessPlaces()
        if let places = try? await BusynessService(http: HTTPClient(timeout: 6)).all() {
            WidgetSnapshotStore.saveBusynessPlaces(places)
            quietest = QuietestLibraryGlance.diningStatusTip(from: places)
            libraryReopenMinutes = QuietestLibraryReload.reopenMinutes(from: places)
            libraryCloseMinutes = QuietestLibraryReload.closeMinutes(from: places)
        } else if let places = busynessCached {
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
                .anteatsWidgetContent()
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
                .widgetURL(AnteatsWidgetURL.eat)
        }
        .configurationDisplayName("Dining Halls")
        .description("Open halls, closes-in, and next meal — glanceable like Nom.")
        // Small + medium cover the job; large only when more halls earn the height.
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

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    private var isCompact: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    private var visibleHalls: ArraySlice<DiningStatusEntry.HallStatus> {
        entry.halls.prefix(DiningStatusLayout.hallLimit(isCompact: isCompact, isLarge: isLarge))
    }
    private var hallCount: Int { visibleHalls.count }
    private var openCount: Int { entry.halls.filter(\.isOpen).count }

    var body: some View {
        VStack(alignment: .leading, spacing: DiningStatusLayout.rowSpacing(isCompact: isCompact, hallCount: max(hallCount, 1))) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text("DINING")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
                if !entry.needsAppRefresh {
                    Text(openCount == 0 ? "Closed" : "\(openCount) open")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(gold.opacity(0.22), in: Capsule())
                        .foregroundStyle(gold)
                }
            }
            .foregroundStyle(gold)

            if entry.needsAppRefresh || entry.halls.isEmpty {
                Spacer(minLength: 0)
                Text(WidgetLoadEmptyCopy.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                Spacer(minLength: 0)
            } else {
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
                                if let line = QuietestLibraryGlance.diningStatusClosedSecondary(
                                    reopenMinutes: reopenMinutes
                                ) {
                                    Text(line)
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
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        let nameSize = DiningStatusLayout.nameFontSize(isCompact: isCompact, hallCount: hallCount)
        let statusSize = DiningStatusLayout.statusFontSize(isCompact: isCompact, hallCount: hallCount)
        return VStack(alignment: .leading, spacing: DiningStatusLayout.usesDenseRows(hallCount: hallCount) ? 0 : 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(hall.isOpen ? Color.green : Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(shortName(hall.name))
                    .font(.system(size: nameSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 3)
                if let end = hall.countdownEnd, let kind = hall.countdownKind, end > Date() {
                    Text(
                        kind == .closes
                            ? WidgetCountdownCopy.closesLine(until: end)
                            : WidgetCountdownCopy.opensLine(until: end)
                    )
                    .font(.system(size: nameSize - 1, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                } else if let occupancy = hall.occupancy {
                    Text("\(occupancy)%")
                        .font(.system(size: nameSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }
            Text(hall.statusText)
                .font(.system(size: statusSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .padding(.leading, 11)
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
        let service = DiningService(http: HTTPClient(timeout: 8))
        let cached = WidgetSnapshotStore.loadDiningLocations() ?? []
        let networked = await service.locations()
        let networkLooksLive = networked.contains {
            !$0.availablePeriods.isEmpty || $0.todayHours != nil || !$0.periods.isEmpty
        }
        let locations = networkLooksLive ? networked : (cached.isEmpty ? networked : cached)
        if networkLooksLive { WidgetSnapshotStore.saveDiningLocations(networked) }
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
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
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
                Link(destination: entry.dishDeepLinkURL(first)) {
                    Text(first)
                        .font(.system(size: 12))
                        .opacity(0.85)
                        .lineLimit(1)
                }
                if entry.dishes.count > 1 {
                    let second = entry.dishes[1]
                    Link(destination: entry.dishDeepLinkURL(second)) {
                        Text(second)
                            .font(.system(size: 12))
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
                            Text(WidgetCountdownCopy.closesLine(until: end))
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                                .lineLimit(1)
                        } else if let open = entry.periodOpensAt, open > Date() {
                            Text(WidgetCountdownCopy.opensLine(until: open))
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(gold)
                                .lineLimit(1)
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

            if let hint = entry.filterHint, !entry.filtersEmptiedMenu {
                Text(hint)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            let dishes = Array(entry.dishes.prefix(dishLimit))
            if dishes.isEmpty {
                Spacer()
                if entry.filtersEmptiedMenu {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nothing matches your Eat Filters.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                        if let hint = entry.filterHint {
                            Text(hint)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(gold.opacity(0.9))
                                .lineLimit(1)
                        }
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
                    Link(destination: entry.dishDeepLinkURL(dish)) {
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
        // One Auto hall only — multi-hall menu fan-out was blowing the widget
        // timeline budget and left sibling glances stuck on placeholders.
        let cached = WidgetSnapshotStore.loadDiningLocations() ?? []
        let networked = await DiningService(http: HTTPClient(timeout: 8)).locations()
        let networkLooksLive = networked.contains {
            !$0.availablePeriods.isEmpty || $0.todayHours != nil || !$0.periods.isEmpty
        }
        let locations = networkLooksLive ? networked : (cached.isEmpty ? networked : cached)
        if networkLooksLive { WidgetSnapshotStore.saveDiningLocations(networked) }
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

        guard let hall = TodaysMenuHallPick.auto(from: locations, nowMinutes: nowMinutes) else {
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

        let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timed,
            availablePeriods: hall.availablePeriods,
            nowMinutes: nowMinutes
        )
        let pill = choice.period
        let service = DiningService(http: HTTPClient(timeout: 8))
        let stations: [MenuStation]
        if !pill.isEmpty, let menu = try? await service.menu(for: hall.id, period: pill) {
            stations = menu.stations
        } else {
            stations = []
        }
        let displayPeriod = MealPeriodDisplay.label(
            live: choice.livePeriodName,
            pill: choice.period
        )
        let rows = FavoritesOnMenuPick.rows(
            favorites: favorites,
            stations: stations,
            hallID: hall.id,
            hallName: hall.name,
            period: displayPeriod
        )

        return FavoritesTodayEntry(
            date: .now,
            hasFavorites: true,
            hallName: hall.name,
            hallID: hall.id,
            period: rows.isEmpty ? nil : displayPeriod,
            dishes: rows.map(\.dishName),
            filterHint: filterHint,
            deepLinkPeriod: displayPeriod.isEmpty ? nil : displayPeriod,
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
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
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

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    private var dishLimit: Int { family == .systemSmall ? 2 : 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("FAVORITES")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
                if let period = entry.period, !period.isEmpty {
                    Text(period)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(gold)

            if let hall = entry.hallName, !entry.dishes.isEmpty {
                Text(hall.hasPrefix("The ") ? String(hall.dropFirst(4)) : hall)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            if let hint = entry.filterHint {
                Text(hint)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if entry.dishes.isEmpty {
                Spacer()
                Text(FavoritesOnMenuPick.emptyTitle(hasFavorites: entry.hasFavorites))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(FavoritesOnMenuPick.emptyMessage(hasFavorites: entry.hasFavorites))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                Spacer()
            } else {
                ForEach(Array(entry.dishes.prefix(dishLimit)), id: \.self) { dish in
                    Link(destination: entry.dishDeepLinkURL(dish)) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(gold)
                            Text(dish)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }
                if entry.dishes.count > dishLimit {
                    Text("+\(entry.dishes.count - dishLimit) more")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
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
        let cached = WidgetSnapshotStore.loadCampusPlaces() ?? []
        if let networked = try? await CampusService(http: HTTPClient(timeout: 8)).places(),
           !networked.isEmpty {
            WidgetSnapshotStore.saveCampusPlaces(networked)
            return networked
        }
        return cached
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
                .anteatsWidgetContent()
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

            if entry.needsAppRefresh {
                Spacer()
                Text(WidgetLoadEmptyCopy.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(WidgetLoadEmptyCopy.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                Spacer()
            } else if entry.openPlaces.isEmpty {
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
        let cached = WidgetSnapshotStore.loadBusynessPlaces() ?? []
        if let networked = try? await BusynessService(http: HTTPClient(timeout: 6)).all(),
           !networked.isEmpty {
            WidgetSnapshotStore.saveBusynessPlaces(networked)
            return Self.entry(from: networked)
        }
        return Self.entry(from: cached)
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
