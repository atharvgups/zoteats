import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuPeriodPick")
struct TodaysMenuPeriodPickTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

    @Test func duringMealUsesCurrentAndEnd() {
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: day,
            availablePeriods: available,
            nowMinutes: 700
        )
        #expect(choice.period == "Lunch")
        #expect(choice.endsAtMinutes == 870)
        #expect(choice.upcomingStartMinutes == nil)
        #expect(!choice.isAfterHours)
    }

    @Test func betweenMealsPicksNextWithoutEndCountdown() {
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: day,
            availablePeriods: available,
            nowMinutes: 900
        )
        #expect(choice.period == "Dinner")
        #expect(choice.endsAtMinutes == nil)
        #expect(choice.upcomingStartMinutes == 990)
        #expect(!choice.isAfterHours)
    }

    @Test func afterLastMealDoesNotFallBackToDinner() {
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: day,
            availablePeriods: available,
            nowMinutes: 1300
        )
        #expect(choice.period.isEmpty)
        #expect(choice.endsAtMinutes == nil)
        #expect(choice.isAfterHours)
    }

    @Test func brunchMapsToBreakfastPillKeepsLiveName() {
        let brunch = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
        ]
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: brunch,
            availablePeriods: ["Brunch", "Dinner"],
            nowMinutes: 700
        )
        #expect(choice.period == "Breakfast")
        #expect(choice.livePeriodName == "Brunch")
        #expect(
            MealPeriodDisplay.label(live: choice.livePeriodName, pill: choice.period) == "Brunch"
        )
    }

    @Test func limitedDinnerKeepsLiveNameForDisplay() {
        let limited = [
            MealPeriodWindow(name: "Limited Dinner", startMinutes: 1020, endMinutes: 1140),
        ]
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: limited,
            availablePeriods: ["Breakfast", "Limited Dinner"],
            nowMinutes: 1050
        )
        #expect(choice.period == "Dinner")
        #expect(choice.livePeriodName == "Limited Dinner")
        #expect(
            MealPeriodDisplay.label(live: choice.livePeriodName, pill: choice.period)
                == "Limited Dinner"
        )
    }
}

@Suite("UCITime — Irvine midnight")
struct IrvineMidnightTests {
    @Test func nextMidnightIsStrictlyTomorrowStart() {
        // Thursday 2026-07-09, 10 PM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")!
        let midnight = UCITime.nextIrvineMidnight(now: now)
        #expect(PacificTime.todayISO(now: midnight) == "2026-07-10")
        #expect(UCITime.nowMinutes(now: midnight) == 0)
        #expect(midnight > now)
    }
}
