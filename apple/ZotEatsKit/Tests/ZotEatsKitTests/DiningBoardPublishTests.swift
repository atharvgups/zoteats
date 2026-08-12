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

    @Test func futurePublishProbesSkipPastSlots() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:05:00Z")! // Mon 11:05 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let probes = DiningBoardPublish.futurePublishProbeDates(
            nowMinutes: nowMinutes,
            now: now
        )
        let lunch = UCITime.date(forMinutes: 11 * 60 + 15, nowMinutes: nowMinutes, now: now)
        let dinner = UCITime.date(forMinutes: 16 * 60 + 15, nowMinutes: nowMinutes, now: now)
        let evening = UCITime.date(forMinutes: 20 * 60, nowMinutes: nowMinutes, now: now)
        #expect(probes.contains(lunch))
        #expect(probes.contains(dinner))
        #expect(probes.contains(evening))
    }

    @Test func earlyLunchPublishProbeBeforeTypicalOpen() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:05:00Z")! // Mon 10:05 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let probes = DiningBoardPublish.futurePublishProbeDates(
            nowMinutes: nowMinutes,
            now: now
        )
        let earlyLunch = UCITime.date(forMinutes: 10 * 60 + 30, nowMinutes: nowMinutes, now: now)
        #expect(probes.contains(earlyLunch))
        #expect(probes.first == earlyLunch)
    }

    @Test func futurePublishProbesEmptyAtEveningConfidence() {
        let now = ISO8601DateFormatter().date(from: "2026-07-14T03:00:00Z")! // Mon 8 PM PDT
        #expect(
            DiningBoardPublish.futurePublishProbeDates(
                nowMinutes: UCITime.nowMinutes(now: now),
                now: now
            ).isEmpty
        )
    }
}
