import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FavoriteAlertPeriods")
struct FavoriteAlertPeriodsTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

    @Test func duringLunchDropsEndedBreakfast() {
        #expect(
            FavoriteAlertPeriods.eligible(
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            ) == ["Lunch", "Dinner"]
        )
    }

    @Test func afterHoursReturnsEmpty() {
        #expect(
            FavoriteAlertPeriods.eligible(
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 1300
            ).isEmpty
        )
    }

    @Test func beforeOpenKeepsAllUpcoming() {
        #expect(
            FavoriteAlertPeriods.eligible(
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 400
            ) == ["Breakfast", "Lunch", "Dinner"]
        )
    }

    @Test func brunchWeekendMapsBreakfastPill() {
        let brunchDay = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        #expect(
            FavoriteAlertPeriods.eligible(
                timedPeriods: brunchDay,
                availablePeriods: ["Brunch", "Dinner"],
                nowMinutes: 700
            ) == ["Breakfast", "Dinner"]
        )
    }
}
