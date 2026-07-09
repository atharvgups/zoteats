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
        #expect(locations.map(\.id) == [.anteatery, .brandywine])
        #expect(locations[0].name == "The Anteatery")
        #expect(locations[0].area == "Mesa Court")
        #expect(locations[1].name == "Brandywine")
    }

    @Test func locationsExposeHoursAndPeriods() async {
        let anteatery = await service().locations().first { $0.id == .anteatery }!
        #expect(anteatery.todayHours == "7:15 AM – 8:00 PM")
        #expect(!anteatery.availablePeriods.isEmpty)
        // Fixed clock is 12:30 PM Pacific — inside the serving window.
        #expect(anteatery.openNow)
    }

    @Test func menuGroupsDishesByStationWithNutrition() async throws {
        let menu = try await service().menu(for: .anteatery, period: "Lunch", date: "2026-07-09")
        #expect(menu.locationId == .anteatery)
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
        let menu = try await service().menu(for: .anteatery, period: "lUnCh", date: "2026-07-09")
        #expect(!menu.stations.isEmpty)
    }

    @Test func unknownPeriodReturnsEmptyMenuNotError() async throws {
        let menu = try await service().menu(for: .anteatery, period: "Midnight Snack", date: "2026-07-09")
        #expect(menu.stations.isEmpty)
    }

    @Test func networkFailureDegradesToClosedLocations() async {
        let service = DiningService(http: FailingHTTP(), now: { fixtureNoon })
        let locations = await service.locations()
        #expect(locations.count == 2)
        #expect(locations.allSatisfy { !$0.openNow && $0.todayHours == nil && $0.availablePeriods.isEmpty })
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
