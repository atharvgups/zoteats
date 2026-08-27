import Foundation
import Observation
import SwiftUI
import ZotEatsKit

// Observable stores bridging ZotEatsKit services to SwiftUI.
// Services already cache aggressively (TTLCache), so stores can refetch freely.

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
@Observable
final class DiningStore {
    private let service: DiningService

    var locations: LoadState<[DiningLocation]> = .idle
    /// Inclusive ISO window the feed currently publishes — clamps the day strip.
    private(set) var publishedDateRange: DiningService.PublishedDateRange?
    /// Per-hall days that actually have a posted board (not every day in the window).
    private(set) var postedMenuDates: [String: Set<String>] = [:]
    /// Keyed by "\(hallID)|\(period)|\(date ?? "today")".
    private(set) var menus: [String: LoadState<DiningMenu>] = [:]
    /// Future-day meal windows keyed by "\(hallID)|\(dateISO)" — Eat pills/snap
    /// must not reuse today's Brunch schedule when browsing tomorrow.
    private(set) var dayPeriods: [String: LoadState<[MealPeriodWindow]>] = [:]
    /// Irvine day `locations` were last loaded for — drives overnight rollover.
    private(set) var locationsDateISO: String?
    /// Bumps when live `"today"` menus are purged so Eat's `.task(id:)` refetches.
    private(set) var dayEpoch: Int = 0

    init(service: DiningService = DiningService()) {
        self.service = service
        if let cached = WidgetSnapshotStore.loadDiningLocationsIfCurrentDay() {
            locations = .loaded(cached)
            locationsDateISO = UCITime.todayISO()
        }
        for menu in WidgetSnapshotStore.loadDiningMenusIfCurrentDay() {
            let pill = MealPeriodPill.canonical(menu.period)
            menus["\(menu.locationId)|\(pill)|today"] = .loaded(menu)
        }
    }

    /// Purge stale live menus after Irvine midnight. Returns true when a refetch is needed.
    @discardableResult
    func ensureCurrentDay(todayISO: String = UCITime.todayISO()) -> Bool {
        guard DiningDayMath.shouldRollover(loadedDateISO: locationsDateISO, todayISO: todayISO) else {
            return false
        }
        menus = menus.filter { !DiningDayMath.isLiveTodayMenuKey($0.key) }
        dayPeriods = [:]
        postedMenuDates = [:]
        postedDatesScheduled = false
        locationsDateISO = nil
        dayEpoch += 1
        return true
    }

    func dayPeriodsState(hall: String, dateISO: String) -> LoadState<[MealPeriodWindow]> {
        dayPeriods["\(hall)|\(dateISO)"] ?? .idle
    }

    func loadDayPeriods(hall: String, dateISO: String, forceRefresh: Bool = false) async {
        let key = "\(hall)|\(dateISO)"
        if dayPeriods[key]?.value == nil { dayPeriods[key] = .loading }
        let next = await service.mealPeriods(for: hall, dateISO: dateISO, forceRefresh: forceRefresh)
        if dayPeriods[key]?.value != next {
            dayPeriods[key] = .loaded(next)
        }
    }

    func loadLocations(forceRefresh: Bool = false) async {
        if !forceRefresh, locations.value != nil {
            Task { await self.fetchLocations(forceRefresh: false) }
            return
        }
        await fetchLocations(forceRefresh: forceRefresh)
    }

    private func fetchLocations(forceRefresh: Bool) async {
        if locations.value == nil { locations = .loading }
        async let range = service.publishedDateRange(forceRefresh: forceRefresh)
        let result = await service.locations(forceRefresh: forceRefresh)
        let nextRange = await range
        if publishedDateRange != nextRange {
            publishedDateRange = nextRange
        }
        locationsDateISO = UCITime.todayISO()
        let previous = locations.value
        // The service degrades per-hall; treat "no data at all" as an error
        // only when we have nothing to paint (keep last-known halls on screen).
        if result.allSatisfy({ $0.availablePeriods.isEmpty && $0.todayHours == nil }) {
            if locations.value == nil {
                locations = .failed("UCI Dining isn't reachable right now.")
            }
        } else if locations.value != result {
            locations = .loaded(result)
        }
        // App Group snapshot so Home Screen widgets show real text without
        // waiting on a cold network fetch inside the extension process.
        if locations.value != previous, let loaded = locations.value, !loaded.isEmpty {
            WidgetSnapshotStore.saveDiningLocations(loaded)
            WidgetReloader.reloadEatWidgets()
        }
        if forceRefresh {
            Task { await self.refreshPostedMenuDates(forceRefresh: true) }
        }
    }

    private var postedDatesScheduled = false

    func refreshPostedMenuDates(forceRefresh: Bool = false) async {
        let halls = (locations.value ?? []).filter { !$0.isComingSoon }.map(\.id)
        guard !halls.isEmpty else { return }
        let fromISO = fromISOForPostedDates
        let throughISO = throughISOForPostedDates
        let diningService = service
        await withTaskGroup(of: (String, Set<String>).self) { group in
            for hall in halls {
                group.addTask {
                    let dates = await diningService.postedMenuDates(
                        hall: hall,
                        fromISO: fromISO,
                        throughISO: throughISO,
                        forceRefresh: forceRefresh
                    )
                    return (hall, dates)
                }
            }
            for await (hall, dates) in group {
                if postedMenuDates[hall] != dates {
                    postedMenuDates[hall] = dates
                }
            }
        }
    }

    private var fromISOForPostedDates: String {
        let today = UCITime.todayISO()
        return max(today, publishedDateRange?.earliest ?? today)
    }

    private var throughISOForPostedDates: String {
        publishedDateRange?.latest ?? UCITime.todayISO()
    }

    func loadPostedMenuDates(hall: String, forceRefresh: Bool = false) async {
        let today = UCITime.todayISO()
        let latest = publishedDateRange?.latest ?? today
        let from = max(today, publishedDateRange?.earliest ?? today)
        let dates = await service.postedMenuDates(
            hall: hall,
            fromISO: from,
            throughISO: latest,
            forceRefresh: forceRefresh
        )
        if postedMenuDates[hall] != dates {
            postedMenuDates[hall] = dates
        }
    }

    func menuState(hall: String, period: String, date: String? = nil) -> LoadState<DiningMenu> {
        menus["\(hall)|\(period)|\(date ?? "today")"] ?? .idle
    }

    func loadMenu(
        hall: String,
        period: String,
        date: String? = nil,
        forceRefresh: Bool = false,
        reloadWidgets: Bool = true
    ) async {
        let key = "\(hall)|\(period)|\(date ?? "today")"
        if menus[key]?.value == nil {
            if date == nil,
               let cached = WidgetSnapshotStore.loadDiningMenu(
                   hall: hall,
                   period: period,
                   dateISO: UCITime.todayISO()
               ) {
                menus[key] = .loaded(cached)
            } else {
                menus[key] = .loading
            }
        }
        if !forceRefresh, let current = menus[key]?.value, !current.stations.isEmpty {
            Task {
                await self.fetchMenu(
                    hall: hall,
                    period: period,
                    date: date,
                    forceRefresh: false,
                    reloadWidgets: reloadWidgets,
                    key: key
                )
            }
            return
        }
        await fetchMenu(
            hall: hall,
            period: period,
            date: date,
            forceRefresh: forceRefresh,
            reloadWidgets: reloadWidgets,
            key: key
        )
    }

    private func fetchMenu(
        hall: String,
        period: String,
        date: String?,
        forceRefresh: Bool,
        reloadWidgets: Bool,
        key: String
    ) async {
        do {
            let next = try await service.menu(
                for: hall,
                period: period,
                date: date,
                forceRefresh: forceRefresh,
                includeHubDietTags: false
            )
            // Paint the Anteater board immediately; hub tags merge next.
            let changed = menus[key]?.value != next
            if changed {
                menus[key] = .loaded(next)
            }
            if date == nil, changed {
                WidgetSnapshotStore.saveDiningMenu(next)
                if reloadWidgets {
                    WidgetReloader.reloadEatWidgets()
                }
            }
            if date == nil, !postedDatesScheduled {
                postedDatesScheduled = true
                Task { await self.refreshPostedMenuDates(forceRefresh: false) }
            }
            if !next.stations.isEmpty {
                let dining = service
                let hallID = hall
                let meal = period
                let iso = date
                let menuKey = key
                Task {
                    guard let enriched = try? await dining.menu(
                        for: hallID,
                        period: meal,
                        date: iso,
                        forceRefresh: false,
                        includeHubDietTags: true
                    ) else { return }
                    if menus[menuKey]?.value != enriched {
                        menus[menuKey] = .loaded(enriched)
                    }
                    if iso == nil {
                        WidgetSnapshotStore.saveDiningMenu(enriched)
                    }
                }
            }
        } catch {
            if menus[key]?.value == nil {
                menus[key] = .failed(error.localizedDescription)
            }
        }
    }

    /// Snapshot today's current meal for sibling live halls into the App Group so
    /// Favorites Today can scan Anteatery + Brandywine without a cold multi-fetch.
    /// Preferred hall is assumed already saved by `loadMenu`.
    func warmWidgetMenusForLiveHalls(
        preferredHall: String?,
        preferredPeriod: String?
    ) async {
        guard let locations = locations.value else { return }
        let nowMinutes = UCITime.nowMinutes()
        let todayISO = UCITime.todayISO()
        var warmed = false
        for hall in locations where !hall.isComingSoon {
            if let preferredHall, hall.id == preferredHall { continue }
            let timed = hall.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
            let choice = TodaysMenuPeriodPick.choose(
                timedPeriods: timed,
                availablePeriods: hall.availablePeriods,
                nowMinutes: nowMinutes
            )
            // Prefer the same meal pill the user is browsing when that meal exists
            // on the sibling board (peek Lunch at both halls).
            let pill: String
            if let preferred = preferredPeriod,
               !preferred.isEmpty,
               DiningService.primaryPeriods(from: hall.availablePeriods)
                .contains(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
                pill = preferred
            } else {
                pill = choice.period
            }
            guard !pill.isEmpty else { continue }
            if let cached = WidgetSnapshotStore.loadDiningMenu(
                hall: hall.id,
                period: pill,
                dateISO: todayISO
            ), !cached.stations.isEmpty {
                continue
            }
            await loadMenu(
                hall: hall.id,
                period: pill,
                date: nil,
                forceRefresh: false,
                reloadWidgets: false
            )
            warmed = true
        }
        if warmed {
            WidgetReloader.reloadEatWidgets()
        }
    }

    /// Finish the selected hall's in-flight board first, then peek sibling halls
    /// and the other meal pills so they don't steal the first connection.
    func prefetchAfterSelectedBoard(hall: String, period: String) async {
        _ = try? await service.menu(
            for: hall,
            period: period,
            date: nil,
            forceRefresh: false,
            includeHubDietTags: false
        )
        await warmWidgetMenusForLiveHalls(
            preferredHall: hall,
            preferredPeriod: period
        )
        for pill in DiningService.mealSelectorPills where pill != period {
            Task {
                await self.loadMenu(
                    hall: hall,
                    period: pill,
                    date: nil,
                    forceRefresh: false,
                    reloadWidgets: false
                )
            }
        }
    }
}

#if ANTEATS_ENABLE_GYM
@MainActor
@Observable
final class GymStore {
    private let service: GymService

    var status: LoadState<GymStatus> = .idle

    init(service: GymService = GymService()) {
        self.service = service
    }

    func load() async {
        if status.value == nil { status = .loading }
        status = .loaded(await service.status())
    }
}
#endif

@MainActor
@Observable
final class CampusStore {
    private let service: CampusService

    var places: LoadState<[CampusPlace]> = .idle
    /// Keyed by place id.
    private(set) var menus: [String: LoadState<[MenuStation]>] = [:]

    init(service: CampusService = CampusService()) {
        self.service = service
        if let cached = WidgetSnapshotStore.loadCampusPlacesIfCurrentDay() {
            places = .loaded(cached)
        }
    }

    func loadPlaces(forceRefresh: Bool = false) async {
        if !forceRefresh, places.value != nil {
            Task { await self.fetchPlaces() }
            return
        }
        await fetchPlaces()
    }

    private func fetchPlaces() async {
        if places.value == nil { places = .loading }
        do {
            let next = try await service.places()
            // Boundary ticks recompute openNow from the same schedule — skip
            // churn when nothing actually changed (smoother Campus scroll).
            let changed = places.value != next
            if changed {
                places = .loaded(next)
            }
            if changed, let loaded = places.value, !loaded.isEmpty {
                WidgetSnapshotStore.saveCampusPlaces(loaded)
                WidgetReloader.reloadCampusOpen()
            }
        } catch {
            if places.value == nil {
                places = .failed(error.localizedDescription)
            }
        }
    }

    func menuState(for placeID: String) -> LoadState<[MenuStation]> {
        menus[placeID] ?? .idle
    }

    func loadMenu(for placeID: String, forceRefresh: Bool = false) async {
        let cached = menus[placeID]?.value
        let hasItems = cached?.contains { !$0.items.isEmpty } == true
        if hasItems, !forceRefresh {
            Task { await self.fetchMenu(placeID: placeID, forceRefresh: false) }
            return
        }
        if cached == nil {
            menus[placeID] = .loading
        }
        await fetchMenu(placeID: placeID, forceRefresh: forceRefresh)
    }

    private func fetchMenu(placeID: String, forceRefresh: Bool) async {
        let place = places.value?.first(where: { $0.id == placeID })
        do {
            var next = try await service.menu(
                for: placeID,
                placeName: place?.name,
                forceRefresh: forceRefresh
            )
            // Empty TTL can hide a Hub publish. Probe once for venues that
            // actually post menus; Starbucks-style spots stay instant.
            if !forceRefresh,
               next.allSatisfy({ $0.items.isEmpty }),
               place?.hasMenu == true {
                next = try await service.menu(
                    for: placeID,
                    placeName: place?.name,
                    forceRefresh: true
                )
            }
            if menus[placeID]?.value != next {
                menus[placeID] = .loaded(next)
            } else if case .loading = menus[placeID] {
                menus[placeID] = .loaded(next)
            }
        } catch {
            if menus[placeID]?.value == nil {
                menus[placeID] = .failed(error.localizedDescription)
            }
        }
    }
}

@MainActor
@Observable
final class BusynessStore {
    private let service: BusynessService
    private let libraryHoursService: LibraryHoursService

    var facilities: LoadState<[BusynessPoint]> = .idle
    /// Official Langson + Science building hours (LibCal). Soft-fails empty.
    var libraryHours: [LibraryBuildingHours] = []

    init(
        service: BusynessService = BusynessService(),
        libraryHoursService: LibraryHoursService = LibraryHoursService()
    ) {
        self.service = service
        self.libraryHoursService = libraryHoursService
        if let cached = WidgetSnapshotStore.loadBusynessPlacesIfPresent() {
            facilities = .loaded(cached)
        }
    }

    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, facilities.value != nil {
            Task { await self.fetchFacilities() }
            return
        }
        await fetchFacilities()
    }

    private func fetchFacilities() async {
        if facilities.value == nil { facilities = .loading }
        async let facilitiesTask = service.all()
        async let hoursTask = libraryHoursService.today()
        do {
            let next = try await facilitiesTask
            // Waitz stamps a fresh updatedAt every poll — compare occupancy only.
            let prior = facilities.value
            let unchanged = prior.map {
                BusynessSnapshot.equalsIgnoringFetchTime($0, next)
            } ?? false
            if !unchanged {
                facilities = .loaded(next)
                if let loaded = facilities.value, !loaded.isEmpty {
                    WidgetSnapshotStore.saveBusynessPlaces(loaded)
                    WidgetReloader.reloadStudyWidgets()
                }
            }
        } catch {
            if facilities.value == nil {
                facilities = .failed(error.localizedDescription)
            }
        }
        if let hours = try? await hoursTask, hours != libraryHours {
            libraryHours = hours
        }
    }
}

// MARK: - Preferences (favorites + dietary filter), persisted in UserDefaults

@MainActor
@Observable
final class Preferences {
    private static let legacyDietFilterKey = "zoteats.dietFilter"

    /// Favorite dishes by name (IDs rotate daily; names are stable).
    /// Mirrored into the App Group so Today's Menu widgets can pin them.
    var favoriteDishNames: Set<String> {
        didSet {
            SharedDefaults.setFavoriteDishNames(Array(favoriteDishNames).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Hearted Campus retail place IDs — distinct Favorites shelf; deduped from
    /// the main Campus list (Atharv IA: never double a favorited place as a full card).
    var favoriteCampusPlaceIDs: Set<String> {
        didSet {
            SharedDefaults.setFavoriteCampusPlaceIDs(Array(favoriteCampusPlaceIDs).sorted())
            WidgetReloader.reloadCampusOpen()
        }
    }

    /// Active dietary filter tags (AND). Empty = show everything.
    /// Mirrored into the App Group so Today's Menu honors Eat Filters.
    var dietFilters: Set<String> {
        didSet {
            SharedDefaults.setDietFilters(Array(dietFilters).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Allergens to hide (OR). A dish listing any avoided allergen is filtered out.
    var allergenAvoids: Set<String> {
        didSet {
            SharedDefaults.setAllergenAvoids(Array(allergenAvoids).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Personal dish ratings — on-device only, keyed by dish name.
    var mealReviews: [MealReview] {
        didSet {
            SharedDefaults.setMealReviews(mealReviews)
        }
    }

    /// Convenience for single-filter callers (campus sheet, etc.).
    var dietFilter: String? {
        get { dietFilters.sorted().first }
        set {
            if let newValue {
                dietFilters = [newValue]
            } else {
                dietFilters = []
            }
        }
    }

    var hasActiveMenuFilters: Bool {
        !dietFilters.isEmpty || !allergenAvoids.isEmpty
    }

    init() {
        favoriteDishNames = Set(SharedDefaults.favoriteDishNames())
        favoriteCampusPlaceIDs = Set(SharedDefaults.favoriteCampusPlaceIDs())
        let storedDiets = SharedDefaults.dietFilters()
        if !storedDiets.isEmpty {
            dietFilters = Set(storedDiets)
        } else if let legacy = UserDefaults.standard.string(forKey: Self.legacyDietFilterKey) {
            dietFilters = [legacy]
            UserDefaults.standard.removeObject(forKey: Self.legacyDietFilterKey)
        } else {
            dietFilters = []
        }
        allergenAvoids = Set(SharedDefaults.allergenAvoids())
        mealReviews = SharedDefaults.mealReviews()
        // Init assignments skip didSet — mirror into the App Group for widgets.
        SharedDefaults.setDietFilters(Array(dietFilters).sorted())
        SharedDefaults.setAllergenAvoids(Array(allergenAvoids).sorted())
        SharedDefaults.setFavoriteCampusPlaceIDs(Array(favoriteCampusPlaceIDs).sorted())
        SharedDefaults.setMealReviews(mealReviews)
    }

    func clearMenuFilters() {
        dietFilters = []
        allergenAvoids = []
    }

    /// Re-read Eat Filters from the App Group after the Today’s Menu widget
    /// (or another process) clears or changes them while we were suspended.
    func reloadMenuFiltersFromSharedDefaults() {
        let diets = Set(SharedDefaults.dietFilters())
        let allergens = Set(SharedDefaults.allergenAvoids())
        if diets != dietFilters {
            dietFilters = diets
        }
        if allergens != allergenAvoids {
            allergenAvoids = allergens
        }
    }

    func matchesMenuFilters(_ item: MenuItem) -> Bool {
        MenuFilterMatching.matches(
            item: item,
            dietFilters: dietFilters,
            allergenAvoids: allergenAvoids
        )
    }

    func toggleFavorite(_ dishName: String) {
        if favoriteDishNames.contains(dishName) {
            favoriteDishNames.remove(dishName)
        } else {
            favoriteDishNames.insert(dishName)
        }
        Haptics.soft()
    }

    func isFavorite(_ dishName: String) -> Bool {
        favoriteDishNames.contains(dishName)
    }

    func toggleCampusFavorite(_ placeID: String) {
        if favoriteCampusPlaceIDs.contains(placeID) {
            favoriteCampusPlaceIDs.remove(placeID)
        } else {
            favoriteCampusPlaceIDs.insert(placeID)
        }
        Haptics.soft()
    }

    func isCampusFavorite(_ placeID: String) -> Bool {
        favoriteCampusPlaceIDs.contains(placeID)
    }

    func review(for dishName: String) -> MealReview? {
        MealReviewLogic.lookup(mealReviews, dishName: dishName)
    }

    func setReview(dishName: String, stars: Int, note: String, playHaptic: Bool = true) {
        mealReviews = MealReviewLogic.upsert(
            existing: mealReviews,
            dishName: dishName,
            stars: stars,
            note: note
        )
        if playHaptic {
            Haptics.soft()
        }
    }

    func clearReview(dishName: String) {
        mealReviews = MealReviewLogic.remove(existing: mealReviews, dishName: dishName)
        Haptics.soft()
    }
}
