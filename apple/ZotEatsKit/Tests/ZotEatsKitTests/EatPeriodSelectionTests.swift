import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatPeriodSelection")
struct EatPeriodSelectionTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

    @Test func afterHoursClearsStaleDinner() {
        let snapped = EatPeriodSelection.snap(
            current: "Dinner",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 1300,
            browsingFutureDay: false
        )
        #expect(snapped == nil)
    }

    @Test func lunchStaysLunchWhenStillServing() {
        let snapped = EatPeriodSelection.snap(
            current: "Lunch",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 700,
            browsingFutureDay: false
        )
        #expect(snapped == "Lunch")
    }

    @Test func emptyTodayPicksLiveMeal() {
        let snapped = EatPeriodSelection.snap(
            current: nil,
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 700,
            browsingFutureDay: false
        )
        #expect(snapped == "Lunch")
    }

    @Test func betweenMealsPicksUpcomingDinner() {
        let snapped = EatPeriodSelection.snap(
            current: nil,
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 900,
            browsingFutureDay: false
        )
        #expect(snapped == "Dinner")
    }

    @Test func futureDayKeepsValidPill() {
        let snapped = EatPeriodSelection.snap(
            current: "Breakfast",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 1300,
            browsingFutureDay: true
        )
        #expect(snapped == "Breakfast")
    }

    @Test func futureDayDefaultsToFirstPill() {
        let snapped = EatPeriodSelection.snap(
            current: nil,
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 1300,
            browsingFutureDay: true
        )
        #expect(snapped == "Breakfast")
    }

    @Test func stickyUpcomingPillSurvivesIntoEarlierMealWithoutDeeplink() {
        // Upcoming Dinner sticks through Lunch when the user only changes hall —
        // Dining Status should still send period= for an intentional meal jump.
        let snapped = EatPeriodSelection.snap(
            current: "Dinner",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 700,
            browsingFutureDay: false
        )
        #expect(snapped == "Dinner")
    }

    @Test func endedStickyPillAdvancesToUpcoming() {
        // Breakfast ended at 630; between meals at 640 → Lunch (not stale Breakfast).
        let snapped = EatPeriodSelection.snap(
            current: "Breakfast",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 640,
            browsingFutureDay: false
        )
        #expect(snapped == "Lunch")
    }

    @Test func endedStickyLunchAdvancesToDinnerBetweenMeals() {
        let snapped = EatPeriodSelection.snap(
            current: "Lunch",
            availablePeriods: available,
            timedPeriods: day,
            nowMinutes: 900,
            browsingFutureDay: false
        )
        #expect(snapped == "Dinner")
    }
}
