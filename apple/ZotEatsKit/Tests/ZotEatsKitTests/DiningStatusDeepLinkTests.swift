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

    @Test func awaitingMoreMealsStaysOnTodayWithoutDate() {
        let dest = DiningStatusDeepLink.destination(
            for: .awaitingMoreMeals,
            availablePeriods: available,
            opensTomorrowAtMinutes: 435,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == nil)
        #expect(dest.date == nil)
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

    @Test func afterHoursTomorrowCanonicalIgnoresTodaysWeekendPills() {
        // Saturday Brunch+Dinner overnight; tomorrow opens with Lunch.
        let dest = DiningStatusDeepLink.destination(
            for: .closedForToday,
            availablePeriods: ["Brunch", "Dinner"],
            opensTomorrowAtMinutes: 11 * 60,
            opensTomorrowPeriod: "Lunch",
            now: evening
        )
        #expect(dest.period == "Lunch")
        #expect(dest.date != nil)
    }

    @Test func afterHoursTomorrowBrunchMapsToBreakfastPill() {
        let dest = DiningStatusDeepLink.destination(
            for: .closedForToday,
            availablePeriods: ["Breakfast", "Lunch", "Dinner"],
            opensTomorrowAtMinutes: 10 * 60,
            opensTomorrowPeriod: "Brunch",
            now: evening
        )
        #expect(dest.period == "Breakfast")
        #expect(dest.date != nil)
    }
}
