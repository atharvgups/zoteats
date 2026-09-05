import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealTrackWindow")
struct MealTrackWindowTests {
    @Test func breakfastPillMapsToBrunchWindow() {
        let periods = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let window = MealTrackWindow.resolve(
            pill: "Breakfast",
            timedPeriods: periods,
            availablePeriods: ["Brunch", "Dinner"]
        )
        #expect(window?.livePeriodName == "Brunch")
        #expect(window?.startMinutes == 600)
        #expect(window?.endMinutes == 840)
    }

    @Test func dinnerPillMapsToLimitedDinnerWindow() {
        let periods = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Limited Dinner", startMinutes: 1020, endMinutes: 1140),
        ]
        let window = MealTrackWindow.resolve(
            pill: "Dinner",
            timedPeriods: periods,
            availablePeriods: ["Breakfast", "Limited Dinner"]
        )
        #expect(window?.livePeriodName == "Limited Dinner")
        #expect(window?.startMinutes == 1020)
        #expect(window?.endMinutes == 1140)
    }

    @Test func exactBreakfastWeekdayStillWorks() {
        let periods = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let window = MealTrackWindow.resolve(
            pill: "Breakfast",
            timedPeriods: periods,
            availablePeriods: ["Breakfast", "Lunch", "Dinner"]
        )
        #expect(window?.livePeriodName == "Breakfast")
    }

    @Test func missingTimedWindowReturnsNil() {
        let periods = [
            MealPeriodWindow(name: "Brunch", startMinutes: nil, endMinutes: nil),
        ]
        #expect(
            MealTrackWindow.resolve(
                pill: "Breakfast",
                timedPeriods: periods,
                availablePeriods: ["Brunch"]
            ) == nil
        )
    }
}
