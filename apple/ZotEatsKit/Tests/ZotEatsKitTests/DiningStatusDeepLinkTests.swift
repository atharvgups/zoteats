import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusDeepLink")
struct DiningStatusDeepLinkTests {
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]
    private let evening = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT

    @Test func openMealMapsToPrimaryPill() {
        #expect(
            DiningStatusDeepLink.period(
                for: .open(period: "Lunch", closesAt: 870),
                availablePeriods: available
            ) == "Lunch"
        )
        #expect(
            DiningStatusDeepLink.period(
                for: .open(period: "Brunch", closesAt: 840),
                availablePeriods: ["Brunch", "Dinner"]
            ) == "Breakfast"
        )
    }

    @Test func openingLaterIncludesUpcomingMeal() {
        #expect(
            DiningStatusDeepLink.period(
                for: .openingLater(period: "Dinner", opensAt: 990),
                availablePeriods: available
            ) == "Dinner"
        )
    }

    @Test func afterHoursWithoutTomorrowOmitsDestination() {
        let dest = DiningStatusDeepLink.destination(
            for: .closedForToday,
            availablePeriods: available
        )
        #expect(dest.period == nil)
        #expect(dest.date == nil)
        #expect(
            DiningStatusDeepLink.period(
                for: .unknown,
                availablePeriods: available
            ) == nil
        )
    }

    @Test func afterHoursWithTomorrowLinksToTomorrowBoard() {
        let dest = DiningStatusDeepLink.destination(
            for: .closedForToday,
            availablePeriods: available,
            opensTomorrowAtMinutes: 435,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Breakfast")
        let tomorrow = UCITime.upcomingDays(count: 2, now: evening).dropFirst().first?.isoDate
        #expect(dest.date == tomorrow)
        #expect(dest.date != nil)
    }
}
