import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FavoriteAlertCopy")
struct FavoriteAlertCopyTests {
    @Test func liveUsesBeingServedNow() {
        #expect(
            FavoriteAlertCopy.body(
                hallName: "The Anteatery",
                period: "Lunch",
                servingNow: true
            ) == "Being served now at The Anteatery for lunch."
        )
    }

    @Test func upcomingUsesOnTodaysMenu() {
        #expect(
            FavoriteAlertCopy.body(
                hallName: "Brandywine",
                period: "Limited Dinner",
                servingNow: false
            ) == "On today's limited dinner menu at Brandywine."
        )
    }
}

@Suite("MealPillLiveness — currently serving")
struct MealPillLivenessServingTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner"]

    @Test func lunchIsServingDuringLunch() {
        #expect(
            MealPillLiveness.isCurrentlyServing(
                pill: "Lunch",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
        #expect(
            !MealPillLiveness.isCurrentlyServing(
                pill: "Dinner",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
    }

    @Test func dinnerIsLiveOrUpcomingButNotServingBeforeOpen() {
        #expect(
            MealPillLiveness.isLiveOrUpcoming(
                pill: "Dinner",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
        #expect(
            !MealPillLiveness.isCurrentlyServing(
                pill: "Dinner",
                timedPeriods: day,
                availablePeriods: available,
                nowMinutes: 700
            )
        )
    }
}
