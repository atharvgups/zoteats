import Foundation
import Testing
@testable import ZotEatsKit

/// Fixed clock: 2026-07-09 12:30 PM Pacific (19:30 UTC) — matches the captured fixtures.
private let fixtureNoon = ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")!

@Suite("DiningService (fixtures)")
struct DiningServiceTests {
    private func service() -> DiningService {
        DiningService(http: FixtureHTTP(), dayCache: tempDayCache(), now: { fixtureNoon })
    }

    @Test func locationsIncludeBothHallsInStableOrder() async {
        let locations = await service().locations()
        #expect(locations.map(\.id) == ["anteatery", "brandywine"])
        #expect(locations[0].name == "The Anteatery")
        #expect(locations[0].area == "Mesa Court")
        #expect(locations[1].name == "Brandywine")
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
        let service = DiningService(http: FailingHTTP(), dayCache: tempDayCache(), now: { fixtureNoon })
        let locations = await service.locations()
        #expect(locations.count == 2)
        #expect(locations.allSatisfy { !$0.openNow && $0.todayHours == nil && $0.availablePeriods.isEmpty })
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

    @Test func noPeriodsMeansUnknown() {
        #expect(hall(periods: []).openState(nowMinutes: 700) == .unknown)
    }

    @Test func countdownFormatting() {
        #expect(UCITime.countdown(from: 700, to: 745) == "45m")
        #expect(UCITime.countdown(from: 700, to: 770) == "1h 10m")
        #expect(UCITime.countdown(from: 700, to: 820) == "2h")
    }

    @Test func liveLocationsCarryPeriodWindows() async {
        let service = DiningService(http: FixtureHTTP(), dayCache: tempDayCache(), now: { ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")! })
        let anteatery = await service.locations().first { $0.id == "anteatery" }!
        #expect(!anteatery.periods.isEmpty)
        // Some periods (e.g. "All Day") legitimately have no serving window;
        // the timed ones must carry both bounds.
        #expect(anteatery.periods.contains { $0.startMinutes != nil && $0.endMinutes != nil })
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
    }

    @Test func unknownFutureHallsGetReadableNames() {
        // When UCI opens the third commons, its API id renders sensibly with no code change.
        #expect(HallDirectory.displayName(for: "middle-earth-towers") == "Middle Earth Towers")
        #expect(HallDirectory.displayName(for: "el_mercado") == "El Mercado")
        #expect(HallDirectory.area(for: "middle-earth-towers") == "UCI Campus")
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
