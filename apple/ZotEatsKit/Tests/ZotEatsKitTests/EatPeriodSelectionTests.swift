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

    @Test func futureDayUsesThatDaysPillsNotTodaysBrunch() {
        // Weekend overnight → weekday Lunch board (today would have been Brunch/Dinner).
        let weekday = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let snapped = EatPeriodSelection.snap(
            current: "Breakfast",
            availablePeriods: weekday.map(\.name),
            timedPeriods: weekday,
            nowMinutes: 1300,
            browsingFutureDay: true
        )
        #expect(snapped == "Breakfast")
        #expect(
            EatPeriodSelection.snap(
                current: "Dinner",
                availablePeriods: ["Brunch", "Dinner"],
                timedPeriods: [
                    MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
                    MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
                ],
                nowMinutes: 1300,
                browsingFutureDay: true
            ) == "Dinner"
        )
        // Lunch appears once browse-day periods are the weekday board.
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Breakfast",
                availablePeriods: weekday.map(\.name),
                timedPeriods: weekday,
                nowMinutes: 1300,
                browsingFutureDay: true
            ) == "Breakfast"
        )
        #expect(
            DiningService.primaryPeriods(from: weekday.map(\.name)).contains("Lunch")
        )
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

    @Test func breakfastOnlyBoardKeepsLunchPeekAt7am() {
        // Atharv regression: Lunch/Dinner chips must stay selectable before they post.
        let morning = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        #expect(
            EatPeriodSelection.snap(
                current: "Lunch",
                availablePeriods: ["Breakfast"],
                timedPeriods: morning,
                nowMinutes: 433, // 7:13 AM — Breakfast starts in 2m
                browsingFutureDay: false
            ) == "Lunch"
        )
        #expect(
            EatPeriodSelection.snap(
                current: "Dinner",
                availablePeriods: ["Breakfast"],
                timedPeriods: morning,
                nowMinutes: 433,
                browsingFutureDay: false
            ) == "Dinner"
        )
    }

    @Test func partialBoardAwaitingKeepsLastPostedBreakfast() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        #expect(
            EatPeriodSelection.snap(
                current: nil,
                availablePeriods: ["Breakfast"],
                timedPeriods: partial,
                nowMinutes: 700,
                browsingFutureDay: false
            ) == "Breakfast"
        )
        // Ended sticky still resolves to last posted while awaiting Lunch/Dinner.
        #expect(
            EatPeriodSelection.snap(
                current: "Breakfast",
                availablePeriods: ["Breakfast"],
                timedPeriods: partial,
                nowMinutes: 700,
                browsingFutureDay: false
            ) == "Breakfast"
        )
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Breakfast",
                availablePeriods: ["Breakfast"],
                timedPeriods: partial,
                nowMinutes: 700,
                browsingFutureDay: false
            ) == "Breakfast"
        )
    }
}
