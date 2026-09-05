import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealPillLiveness")
struct MealPillLivenessTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

    @Test func liveMealIsLive() {
        #expect(
            MealPillLiveness.isLiveOrUpcoming(
                pill: "Lunch",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
    }

    @Test func upcomingMealIsLive() {
        #expect(
            MealPillLiveness.isLiveOrUpcoming(
                pill: "Dinner",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
    }

    @Test func endedMealIsNotLive() {
        #expect(
            !MealPillLiveness.isLiveOrUpcoming(
                pill: "Breakfast",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 640
            )
        )
    }
}
