import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusDeepLink")
struct DiningStatusDeepLinkTests {
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

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

    @Test func afterHoursAndUnknownOmitPeriod() {
        #expect(
            DiningStatusDeepLink.period(
                for: .closedForToday,
                availablePeriods: available
            ) == nil
        )
        #expect(
            DiningStatusDeepLink.period(
                for: .unknown,
                availablePeriods: available
            ) == nil
        )
    }
}
