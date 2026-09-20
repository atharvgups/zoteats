import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatMealWindow")
struct EatMealWindowTests {
    @Test func clockCutsMatchHallHours() {
        #expect(EatMealWindow.breakfastEndMinutes == 11 * 60)
        #expect(EatMealWindow.lunchEndMinutes == 14 * 60 + 30)
        #expect(EatMealWindow.clockPill(nowMinutes: 10 * 60 + 59) == "Breakfast")
        #expect(EatMealWindow.clockPill(nowMinutes: 11 * 60) == "Lunch")
        #expect(EatMealWindow.clockPill(nowMinutes: 14 * 60 + 29) == "Lunch")
        #expect(EatMealWindow.clockPill(nowMinutes: 14 * 60 + 30) == "Dinner")
        #expect(EatMealWindow.clockPill(nowMinutes: 15 * 60 + 30) == "Dinner")
    }

    @Test func sundayBrunchBoardFollowsBldCuts() {
        let sunday = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 9 * 60, endMinutes: 11 * 60),
            MealPeriodWindow(name: "Brunch", startMinutes: 11 * 60, endMinutes: 16 * 60 + 30),
            MealPeriodWindow(name: "Dinner", startMinutes: 16 * 60 + 30, endMinutes: 20 * 60),
        ]
        let available = ["Breakfast", "Brunch", "Lunch", "Dinner"]
        #expect(
            EatMealWindow.autoPill(
                timedPeriods: sunday,
                availablePeriods: available,
                nowMinutes: 10 * 60
            ) == "Breakfast"
        )
        #expect(
            EatMealWindow.autoPill(
                timedPeriods: sunday,
                availablePeriods: available,
                nowMinutes: 12 * 60
            ) == "Lunch"
        )
        #expect(
            EatMealWindow.autoPill(
                timedPeriods: sunday,
                availablePeriods: available,
                nowMinutes: 15 * 60 + 30
            ) == "Dinner"
        )
    }

    @Test func breakfastEndsAtTypicalCutWhenOnlyBrunchIsLive() {
        let brunchOnly = [
            MealPeriodWindow(name: "Brunch", startMinutes: 11 * 60, endMinutes: 16 * 60 + 30),
        ]
        let pills = ["Breakfast", "Dinner"]
        #expect(
            !EatMealWindow.hasEnded(
                pill: "Breakfast",
                timedPeriods: brunchOnly,
                pills: pills,
                nowMinutes: 10 * 60
            )
        )
        #expect(
            EatMealWindow.hasEnded(
                pill: "Breakfast",
                timedPeriods: brunchOnly,
                pills: pills,
                nowMinutes: 12 * 60
            )
        )
        #expect(
            EatMealWindow.hasEnded(
                pill: "Lunch",
                timedPeriods: brunchOnly,
                pills: pills,
                nowMinutes: 15 * 60 + 30
            )
        )
    }
}
