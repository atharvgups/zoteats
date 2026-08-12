import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningBoardPublish")
struct DiningBoardPublishTests {
    private let breakfastOnly = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 11 * 60),
    ]
    private let breakfastLunch = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 11 * 60),
        MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60 + 30),
    ]
    private let fullDay = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 11 * 60),
        MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60 + 30),
        MealPeriodWindow(name: "Dinner", startMinutes: 16 * 60 + 30, endMinutes: 20 * 60),
    ]

    @Test func breakfastOnlyMidDayAwaitsMoreMeals() {
        #expect(
            DiningBoardPublish.awaitingLaterMeals(periods: breakfastOnly, nowMinutes: 11 * 60 + 30)
        )
    }

    @Test func breakfastLunchAfternoonWithoutDinnerAwaits() {
        #expect(
            DiningBoardPublish.awaitingLaterMeals(periods: breakfastLunch, nowMinutes: 15 * 60)
        )
    }

    @Test func fullBoardEveningIsConfidentClosed() {
        #expect(
            !DiningBoardPublish.awaitingLaterMeals(periods: fullDay, nowMinutes: 20 * 60 + 30)
        )
    }

    @Test func breakfastOnlyAtEveningConfidenceIsDone() {
        #expect(
            !DiningBoardPublish.awaitingLaterMeals(periods: breakfastOnly, nowMinutes: 20 * 60)
        )
    }

    @Test func stillInWindowIsNotAwaiting() {
        #expect(
            !DiningBoardPublish.awaitingLaterMeals(periods: breakfastOnly, nowMinutes: 9 * 60)
        )
    }

    @Test func betweenFullBoardMealsIsNotAwaiting() {
        #expect(
            !DiningBoardPublish.awaitingLaterMeals(periods: fullDay, nowMinutes: 15 * 60)
        )
    }
}
