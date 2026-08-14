import Foundation
import Testing
@testable import ZotEatsKit

/// Fixed clock: 2026-07-09 12:30 PM Pacific (19:30 UTC) — matches the captured fixtures.
private let fixtureNoon = ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")!

@Suite("DiningService (fixtures)")
struct DiningServiceTests {
    private func service() -> DiningService {
        DiningService(http: FixtureHTTP(), now: { fixtureNoon })
    }

    @Test func locationsIncludeBothHallsInStableOrder() async {
        let locations = await service().locations()
        #expect(locations.map(\.id) == ["anteatery", "brandywine", "oasis"])
        #expect(locations[0].name == "The Anteatery")
        #expect(locations[0].area == "Mesa Court")
        #expect(locations[1].name == "Brandywine")
        #expect(locations[2].isComingSoon)
        #expect(locations[2].name == "The Oasis")
    }

    @Test func locationsExposeHoursAndPeriods() async {
        let anteatery = await service().locations().first { $0.id == "anteatery" }!
        #expect(anteatery.todayHours == "7:15 AM – 8:00 PM")
        #expect(!anteatery.availablePeriods.isEmpty)
        // Fixed clock is 12:30 PM Pacific — inside the serving window.
        #expect(anteatery.openNow)
    }

    @Test func periodsFollowTheDaysNaturalOrder() async {
        // Fixture serves Lunch, Dinner, Breakfast, Brunch (untimed), All Day (untimed).
        let anteatery = await service().locations().first { $0.id == "anteatery" }!
        #expect(anteatery.availablePeriods == ["Breakfast", "Brunch", "Lunch", "Dinner", "All Day"])
    }

    @Test func menuGroupsDishesByStationWithNutrition() async throws {
        let menu = try await service().menu(for: "anteatery", period: "Lunch", date: "2026-07-09")
        #expect(menu.locationId == "anteatery")
        #expect(menu.period == "Lunch")
        #expect(!menu.stations.isEmpty)

        let items = menu.stations.flatMap(\.items)
        #expect(!items.isEmpty)
        #expect(items.contains { $0.calories != nil })
        #expect(items.contains { !$0.dietaryTags.isEmpty })
        // Station IDs resolve to real names, not the fallback.
        #expect(menu.stations.contains { $0.name != "Menu" })

        // Full nutrition label rides along: macros, sodium, and ingredients.
        let labeled = items.compactMap(\.nutrition)
        #expect(labeled.contains { $0.hasMacros })
        #expect(labeled.contains { $0.proteinG != nil && $0.totalCarbsG != nil && $0.totalFatG != nil })
        #expect(labeled.contains { $0.sodiumMg != nil && $0.sugarsG != nil && $0.dietaryFiberG != nil })
        #expect(labeled.contains { $0.ingredients?.isEmpty == false })
    }

    @Test func menuPeriodMatchIsCaseInsensitive() async throws {
        let menu = try await service().menu(for: "anteatery", period: "lUnCh", date: "2026-07-09")
        #expect(!menu.stations.isEmpty)
    }

    @Test func unknownPeriodReturnsEmptyMenuNotError() async throws {
        let menu = try await service().menu(for: "anteatery", period: "Midnight Snack", date: "2026-07-09")
        #expect(menu.stations.isEmpty)
    }

    @Test func networkFailureDegradesToClosedLocations() async {
        let service = DiningService(http: FailingHTTP(), now: { fixtureNoon })
        let locations = await service.locations()
        // Anteatery + Brandywine fallbacks, plus Coming Soon Oasis.
        #expect(locations.count == 3)
        #expect(locations.filter { !$0.isComingSoon }.count == 2)
        #expect(locations.contains { $0.isComingSoon && HallDirectory.isOasis($0.id) })
        #expect(locations.allSatisfy { !$0.openNow && $0.availablePeriods.isEmpty })
    }

    @Test func primaryPeriodsKeepBreakfastLunchDinnerOnly() {
        let available = ["Breakfast", "Brunch", "Lunch", "Dinner", "All Day"]
        #expect(DiningService.primaryPeriods(from: available) == ["Breakfast", "Lunch", "Dinner"])
        #expect(DiningService.primaryPeriods(from: ["Brunch", "Dinner", "All Day"]) == ["Breakfast", "Dinner"])
        #expect(DiningService.primaryPeriods(from: ["All Day"]).isEmpty)
        #expect(DiningService.mealSelectorPills == ["Breakfast", "Lunch", "Dinner"])
    }

    @Test func oasisComingSoonHasNoInventedMenu() {
        let oasis = DiningService.oasisComingSoonLocation()
        #expect(oasis.isComingSoon)
        #expect(oasis.availablePeriods.isEmpty)
        #expect(oasis.periods.isEmpty)
        #expect(oasis.comingSoonSubtitle == "Coming Soon")
        #expect(HallDirectory.campusHubKey(for: oasis.id) == "the-oasis-dining-hall")
    }

    @Test func resolvePeriodMapsBreakfastToBrunch() {
        #expect(DiningService.resolvePeriod("Breakfast", available: ["Brunch", "Dinner"]) == "Brunch")
        #expect(DiningService.resolvePeriod("Lunch", available: ["Lunch", "Dinner"]) == "Lunch")
    }

    @Test func lunchMenuFoldsAllDayIntoAvailableAllDayStation() async throws {
        let menu = try await service().menu(for: "anteatery", period: "Lunch", date: "2026-07-09")
        #expect(menu.stations.contains { $0.name == "Available all day" })
    }

    @Test func mealPeriodsExposeWindowsForADate() async {
        let periods = await service().mealPeriods(for: "anteatery", dateISO: "2026-07-09")
        #expect(!periods.isEmpty)
        #expect(periods.contains { $0.startMinutes != nil && $0.endMinutes != nil })
        #expect(OpeningAlertPlanner.earliestOpening(periods: periods) != nil)
    }

    @Test func dietLookupKeysMatchHubNamingVariants() {
        let keys = DiningService.dietLookupKeys(for: "Vegan Mac & Cheese UCI")
        #expect(keys.contains("vegan mac & cheese"))
        #expect(keys.contains("veganmaccheese"))
        let ae = DiningService.dietLookupKeys(for: "AE Grill Chicken")
        #expect(ae.contains("grill chicken"))
        let sandwich = DiningService.dietLookupKeys(for: "Grilled Herb Chicken Sandwich")
        #expect(sandwich.contains("grilled herb chicken"))
        // Collapse Anteater's double spaces so hub enrichment can match.
        #expect(DiningService.collapseWhitespace("Banana  Berry Smoothie") == "Banana Berry Smoothie")
        #expect(
            DiningService.dietLookupKeys(for: "Banana  Berry Smoothie")
                .contains("banana berry smoothie")
        )
    }

    @Test func unpublishedFutureDayReadsAsNotPostedNotError() async throws {
        // Browsing ahead when the feed 404s must never surface "HTTP 404".
        let service = DiningService(http: NotFoundHTTP(), now: { fixtureNoon })
        let menu = try await service.menu(for: "brandywine", period: "Dinner", date: "2026-08-03")
        #expect(menu.stations.isEmpty)
        #expect(menu.date == "2026-08-03")
    }

    @Test func otherHTTPFailuresStillThrow() async {
        let service = DiningService(http: FailingHTTP(), now: { fixtureNoon })
        await #expect(throws: (any Error).self) {
            _ = try await service.menu(for: "brandywine", period: "Dinner", date: "2026-08-03")
        }
    }

    @Test func publishedDateRangeComesFromFeed() async {
        let range = await service().publishedDateRange()
        #expect(range?.earliest == "2026-02-22")
        #expect(range?.latest == "2026-07-12")
        #expect(range?.contains("2026-07-10") == true)
        #expect(range?.contains("2026-07-13") == false)
    }

    @Test func veganFlagAlsoSurfacesVegetarianTag() async throws {
        // Live API sometimes sets only isVegan; Vegetarian filter must still match.
        let menu = try await service().menu(for: "anteatery", period: "Lunch", date: "2026-07-09")
        let veganItems = DiningService.withStationDietOverrides(menu).stations
            .flatMap(\.items)
            .filter { $0.dietaryTags.contains("Vegan") }
        #expect(!veganItems.isEmpty)
        #expect(veganItems.allSatisfy { $0.dietaryTags.contains("Vegetarian") })
    }

    @Test func twistedRootDishesAreAlwaysVeganAtBothHalls() async throws {
        let untagged = MenuItem(
            id: "x", name: "Mystery Tofu", description: nil, calories: 200,
            servingSize: nil, allergens: ["Soy"], dietaryTags: []
        )

        for station in ["The Twisted Root", "Twisted Root", " the twisted root "] {
            let fixed = DiningService.applyStationTags([untagged], station: station)
            #expect(fixed[0].dietaryTags.contains("Vegan"))
            #expect(fixed[0].dietaryTags.contains("Vegetarian"))
        }

        // Known Anteatery + Brandywine station ids even if the name map fails.
        #expect(
            DiningService.applyStationTags([untagged], station: "Menu", stationID: "1929")[0]
                .dietaryTags.contains("Vegan")
        )
        #expect(
            DiningService.applyStationTags([untagged], station: "Menu", stationID: "1893")[0]
                .dietaryTags.contains("Vegetarian")
        )
        #expect(
            !DiningService.applyStationTags([untagged], station: "Sizzle Grill")[0]
                .dietaryTags.contains("Vegan")
        )

        let menu = try await service().menu(for: "anteatery", period: "Lunch", date: "2026-07-09")
        let twisted = menu.stations.first(where: { $0.name.contains("Twisted Root") })
        #expect(twisted != nil)
        #expect(twisted!.items.allSatisfy { $0.dietaryTags.contains("Vegan") })
        #expect(twisted!.items.allSatisfy { $0.dietaryTags.contains("Vegetarian") })
    }
}

@Suite("HallOpenState")
struct HallOpenStateTests {
    private func hall(periods: [MealPeriodWindow]) -> DiningLocation {
        DiningLocation(
            id: "anteatery", name: "The Anteatery", area: "Mesa Court",
            openNow: false, todayHours: nil,
            availablePeriods: periods.map(\.name), periods: periods,
            hoursApproximate: false
        )
    }

    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),   // 7:15–10:30
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),       // 11:00–14:30
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),     // 16:30–20:00
    ]

    @Test func duringAMealItIsOpenWithClosingTime() {
        #expect(hall(periods: day).openState(nowMinutes: 700) == .open(period: "Lunch", closesAt: 870))
    }

    @Test func betweenMealsItReportsTheNextOne() {
        #expect(hall(periods: day).openState(nowMinutes: 900) == .openingLater(period: "Dinner", opensAt: 990))
    }

    @Test func beforeFirstMealItReportsBreakfast() {
        #expect(hall(periods: day).openState(nowMinutes: 300) == .openingLater(period: "Breakfast", opensAt: 435))
    }

    @Test func afterLastMealItIsClosedForToday() {
        #expect(hall(periods: day).openState(nowMinutes: 1300) == .closedForToday)
    }

    @Test func breakfastOnlyMidDayAwaitsMoreMealsNotTomorrow() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        let location = DiningLocation(
            id: "anteatery", name: "The Anteatery", area: "Mesa Court",
            openNow: false, todayHours: nil,
            availablePeriods: ["Breakfast"], periods: partial,
            hoursApproximate: false,
            opensTomorrowAtMinutes: 435,
            opensTomorrowPeriod: "Breakfast"
        )
        #expect(location.openState(nowMinutes: 700) == .awaitingMoreMeals)
        #expect(
            DiningLocationHoursLine.resolve(
                state: location.openState(nowMinutes: 700),
                todayHours: nil,
                opensTomorrowAtMinutes: location.opensTomorrowAtMinutes,
                opensTomorrowPeriod: location.opensTomorrowPeriod
            ) == "More meals post later"
        )
        #expect(
            DiningStatusDeepLink.destination(
                for: .awaitingMoreMeals,
                availablePeriods: location.availablePeriods,
                opensTomorrowAtMinutes: location.opensTomorrowAtMinutes,
                opensTomorrowPeriod: location.opensTomorrowPeriod,
                timedPeriods: location.periods,
                nowMinutes: 700
            ) == .init(period: "Breakfast")
        )
    }

    @Test func breakfastOnlyAfterEveningConfidenceIsClosedForToday() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        #expect(hall(periods: partial).openState(nowMinutes: 20 * 60) == .closedForToday)
    }

    @Test func isServingTracksWindowsEvenWhenOpenNowSnapshotIsStale() {
        // Fetch-time openNow stayed false (pre-lunch), but periods say Lunch is on.
        let staleClosed = hall(periods: day)
        #expect(!staleClosed.openNow)
        #expect(staleClosed.isServing(nowMinutes: 700))
        #expect(!staleClosed.isServing(nowMinutes: 900))
        #expect(!staleClosed.isServing(nowMinutes: 1300))

        let staleOpen = DiningLocation(
            id: "anteatery", name: "The Anteatery", area: "Mesa Court",
            openNow: true, todayHours: "7:15 AM – 8:00 PM",
            availablePeriods: day.map(\.name), periods: day,
            hoursApproximate: false
        )
        #expect(staleOpen.openNow)
        #expect(!staleOpen.isServing(nowMinutes: 900))
        #expect(staleOpen.isServing(nowMinutes: 700))
    }

    @Test func noPeriodsMeansUnknown() {
        // Before empty-board confidence (10:30) — still "Menu not posted yet".
        let empty = hall(periods: [])
        #expect(empty.openState(nowMinutes: 9 * 60) == .unknown)
        #expect(empty.hoursLine(nowMinutes: 9 * 60) == "Menu not posted yet")
    }

    @Test func emptyBoardAfterLunchProbeIsClosedForToday() {
        let empty = DiningLocation(
            id: "anteatery", name: "The Anteatery", area: "Mesa Court",
            openNow: false, todayHours: nil,
            availablePeriods: [], periods: [],
            hoursApproximate: false,
            opensTomorrowAtMinutes: nil,
            opensTomorrowPeriod: nil,
            opensNextAtMinutes: 7 * 60 + 15,
            opensNextDayOffset: 3,
            opensNextWeekday: "Monday",
            opensNextPeriod: "Breakfast",
            opensNextDateISO: "2026-07-13"
        )
        // Weekend daytime — See Monday without waiting until 8 PM.
        #expect(
            empty.openState(nowMinutes: DiningBoardPublish.emptyBoardConfidenceMinutes)
                == .closedForToday
        )
        #expect(empty.openState(nowMinutes: 12 * 60) == .closedForToday)
        #expect(empty.openState(nowMinutes: 20 * 60) == .closedForToday)
        #expect(
            DiningLocationHoursLine.resolve(
                state: empty.openState(nowMinutes: 12 * 60),
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: empty.opensTomorrowAtMinutes,
                opensTomorrowPeriod: empty.opensTomorrowPeriod,
                opensNextAtMinutes: empty.opensNextAtMinutes,
                opensNextWeekday: empty.opensNextWeekday,
                opensNextPeriod: empty.opensNextPeriod
            ) == "Breakfast Monday · 7:15 AM"
        )
        #expect(
            DiningMenuIdleEmptyKind.resolve(
                browsingToday: true,
                openState: empty.openState(nowMinutes: 12 * 60)
            ) == .afterHours
        )
        #expect(
            DiningMenuIdleEmptyKind.resolve(
                browsingToday: true,
                openState: hall(periods: []).openState(nowMinutes: 9 * 60)
            ) == .noMenuPosted
        )
    }

    @Test func countdownFormatting() {
        #expect(UCITime.countdown(from: 700, to: 745) == "45m")
        #expect(UCITime.countdown(from: 700, to: 770) == "1h 10m")
        #expect(UCITime.countdown(from: 700, to: 820) == "2h")
    }

    @Test func dateForMinutesStaysTodayWhenStillAhead() {
        // Thursday 2026-07-09, noon Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let date = UCITime.date(forMinutes: 13 * 60, nowMinutes: 12 * 60, now: now)
        #expect(UCITime.nowMinutes(now: date) == 13 * 60)
        #expect(PacificTime.todayISO(now: date) == "2026-07-09")
    }

    @Test func dateForMinutesRollsToTomorrowWhenPast() {
        let now = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let date = UCITime.date(forMinutes: 8 * 60, nowMinutes: 12 * 60, now: now)
        #expect(UCITime.nowMinutes(now: date) == 8 * 60)
        #expect(PacificTime.todayISO(now: date) == "2026-07-10")
    }

    @Test func liveLocationsCarryPeriodWindows() async {
        let service = DiningService(http: FixtureHTTP(), now: { ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")! })
        let anteatery = await service.locations().first { $0.id == "anteatery" }!
        #expect(!anteatery.periods.isEmpty)
        // Some periods (e.g. "All Day") legitimately have no serving window;
        // the timed ones must carry both bounds.
        #expect(anteatery.periods.contains { $0.startMinutes != nil && $0.endMinutes != nil })
    }

    @Test func locationsCarryTomorrowsEarliestOpening() async {
        // Evening after dinner — tomorrow open should still be filled from the feed.
        let evening = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // 10 PM PDT
        let service = DiningService(http: FixtureHTTP(), now: { evening })
        let anteatery = await service.locations().first { $0.id == "anteatery" }!
        #expect(anteatery.opensTomorrowAtMinutes != nil)
        #expect(anteatery.opensTomorrowPeriod != nil)
        #expect(anteatery.openState(nowMinutes: UCITime.nowMinutes(now: evening)) == .closedForToday)
    }
}

@Suite("UpcomingDays")
struct UpcomingDaysTests {
    @Test func labelsAndDatesRollForwardInIrvineTime() {
        // Thursday 2026-07-09, 8 PM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        let days = UCITime.upcomingDays(count: 4, now: now)
        #expect(days.count == 4)
        #expect(days[0].isoDate == "2026-07-09")
        #expect(days[0].label == "Today")
        #expect(days[1].isoDate == "2026-07-10")
        #expect(days[1].label == "Tomorrow")
        #expect(days[2].label == "Sat 11")
        #expect(days[3].isoDate == "2026-07-12")
    }
}

@Suite("HallDirectory")
struct HallDirectoryTests {
    @Test func knownHallsKeepCuratedNames() {
        #expect(HallDirectory.displayName(for: "anteatery") == "The Anteatery")
        #expect(HallDirectory.area(for: "brandywine") == "Middle Earth")
        #expect(HallDirectory.compactName(for: "anteatery") == "Anteatery")
        #expect(HallDirectory.compactName(for: "brandywine") == "Brandywine")
        #expect(HallDirectory.compactName(for: "oasis") == "Oasis")
    }

    @Test func thirdCommonsAliasesAreCuratedForSeptember() {
        #expect(HallDirectory.displayName(for: "mesa-commons") == "Mesa Commons")
        #expect(HallDirectory.area(for: "mesa-commons") == "Mesa Court")
        #expect(HallDirectory.displayName(for: "middle-earth-towers") == "Middle Earth Towers Dining")
        #expect(HallDirectory.displayName(for: "oasis") == "The Oasis")
        #expect(HallDirectory.area(for: "oasis") == "Mesa Court")
        #expect(HallDirectory.isOasis("the-oasis-dining-hall"))
        #expect(HallDirectory.campusHubKey(for: "anteatery") == "the-anteatery")
        #expect(HallDirectory.fallbackIDs == ["anteatery", "brandywine"])
    }

    @Test func unknownFutureHallsGetReadableNames() {
        // Truly unknown ids still prettify with no code change.
        #expect(HallDirectory.displayName(for: "el_mercado") == "El Mercado")
        #expect(HallDirectory.area(for: "el_mercado") == "UCI Campus")
    }

    @Test func matchingDisplayNameFindsKnownHalls() {
        #expect(HallDirectory.id(matchingDisplayName: "The Anteatery") == "anteatery")
        // Case-insensitive — cold-start sync may see either casing.
        #expect(HallDirectory.id(matchingDisplayName: "Brandywine") == "brandywine")
        #expect(HallDirectory.id(matchingDisplayName: "brandywine") == "brandywine")
        #expect(HallDirectory.id(matchingDisplayName: "Mesa Commons") == "mesa-commons")
        #expect(HallDirectory.id(matchingDisplayName: "  The Anteatery  ") == "anteatery")
        #expect(HallDirectory.id(matchingDisplayName: "Unknown Hall") == nil)
        #expect(HallDirectory.id(matchingDisplayName: "") == nil)
    }

    @Test("forceRefresh replaces cached empty board before today TTL expires")
    func forceRefreshBypassesStaleEmptyTodayBoard() async {
        let http = PublishProbeHTTP()
        let cache = TTLCache()
        let service = DiningService(http: http, cache: cache, now: { fixtureNoon })

        let before = await service.locations()
        #expect(before.allSatisfy { $0.availablePeriods.isEmpty })
        let hitsAfterEmpty = await http.todayHits()
        #expect(hitsAfterEmpty >= 1)

        // Soft reload within TTL must reuse the empty board (no new today hits).
        let soft = await service.locations()
        #expect(soft.allSatisfy { $0.availablePeriods.isEmpty })
        #expect(await http.todayHits() == hitsAfterEmpty)

        await http.publish()
        let softStillStale = await service.locations()
        #expect(softStillStale.allSatisfy { $0.availablePeriods.isEmpty })
        #expect(await http.todayHits() == hitsAfterEmpty)

        let fresh = await service.locations(forceRefresh: true)
        #expect(fresh.contains { $0.availablePeriods.contains("Lunch") })
        #expect(await http.todayHits() > hitsAfterEmpty)
    }

    @Test("forceRefresh refreshes tomorrow opens-at when next-day board publishes")
    func forceRefreshUpdatesOpensTomorrowMetadata() async {
        // Thursday 9:00 PM Pacific — after Dinner; tomorrow is Friday 2026-07-10.
        let evening = ISO8601DateFormatter().date(from: "2026-07-10T04:00:00Z")!
        let todayISO = "2026-07-09"
        let tomorrowISO = "2026-07-10"
        let http = TomorrowPublishHTTP(todayISO: todayISO)
        let cache = TTLCache()
        let service = DiningService(http: http, cache: cache, now: { evening })

        let before = await service.locations()
        #expect(before.contains { !$0.availablePeriods.isEmpty })
        #expect(before.allSatisfy { $0.opensTomorrowAtMinutes == nil })
        let tomorrowHits = await http.hits(for: tomorrowISO)
        #expect(tomorrowHits >= 1)

        await http.publish(dateISO: tomorrowISO)
        let soft = await service.locations()
        #expect(soft.allSatisfy { $0.opensTomorrowAtMinutes == nil })
        #expect(await http.hits(for: tomorrowISO) == tomorrowHits)

        let fresh = await service.locations(forceRefresh: true)
        #expect(fresh.contains { $0.opensTomorrowAtMinutes == 7 * 60 + 15 })
        #expect(fresh.contains { $0.opensTomorrowPeriod == "Breakfast" })
        #expect(await http.hits(for: tomorrowISO) > tomorrowHits)
    }
}

@Suite("PacificTime")
struct PacificTimeTests {
    @Test func parsesAndFormatsMinutes() {
        #expect(PacificTime.parseMinutes("07:15") == 435)
        #expect(PacificTime.parseMinutes("20:00") == 1200)
        #expect(PacificTime.parseMinutes(nil) == nil)
        #expect(PacificTime.formatMinutes(435) == "7:15 AM")
        #expect(PacificTime.formatMinutes(1200) == "8:00 PM")
        #expect(PacificTime.formatMinutes(0) == "12:00 AM")
        #expect(PacificTime.formatMinutes(720) == "12:00 PM")
    }

    @Test func pinsDateToIrvine() {
        // 2026-07-10 03:00 UTC is still 2026-07-09 8:00 PM in Irvine (PDT).
        let lateUTC = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        #expect(PacificTime.todayISO(now: lateUTC) == "2026-07-09")
        #expect(PacificTime.nowMinutes(now: lateUTC) == 20 * 60)
        #expect(PacificTime.weekdayName(now: lateUTC) == "Thursday")
    }
}

@Suite("UCITime — public Pacific facade")
struct UCITimePublicFacadeTests {
    @Test func weekdayAndTodayMatchPacific() {
        let lateUTC = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        #expect(UCITime.todayISO(now: lateUTC) == PacificTime.todayISO(now: lateUTC))
        #expect(UCITime.weekdayName(now: lateUTC) == PacificTime.weekdayName(now: lateUTC))
        #expect(UCITime.todayISO(now: lateUTC) == "2026-07-09")
        #expect(UCITime.weekdayName(now: lateUTC) == "Thursday")
    }
}
