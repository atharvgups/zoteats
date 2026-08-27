import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealActivityAutoStart")
struct MealActivityAutoStartTests {
    private func hall(
        id: String,
        name: String,
        periods: [MealPeriodWindow],
        opensTomorrowPeriod: String? = "Breakfast"
    ) -> DiningLocation {
        DiningLocation(
            id: id,
            name: name,
            area: "UTC",
            openNow: true,
            todayHours: nil,
            availablePeriods: periods.map(\.name),
            periods: periods,
            hoursApproximate: false,
            opensTomorrowAtMinutes: 435,
            opensTomorrowPeriod: opensTomorrowPeriod
        )
    }

    private let weekday = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]

    @Test func picksLunchInsideWrapUpWindow() {
        // Lunch ends 870 → auto from 825. Sit at 830.
        let pick = MealActivityAutoStart.pick(
            locations: [hall(id: "anteatery", name: "The Anteatery", periods: weekday)],
            nowMinutes: 830,
            alreadyTracking: false,
            autoEnabled: true
        )
        #expect(pick?.livePeriodName == "Lunch")
        #expect(pick?.hallID == "anteatery")
        #expect(pick?.endMinutes == 870)
    }

    @Test func nilWhenOutsideWrapUp() {
        let pick = MealActivityAutoStart.pick(
            locations: [hall(id: "anteatery", name: "The Anteatery", periods: weekday)],
            nowMinutes: 700, // mid-lunch, >45m left
            alreadyTracking: false,
            autoEnabled: true
        )
        #expect(pick == nil)
    }

    @Test func respectsAlreadyTrackingAndDisabled() {
        let locations = [hall(id: "anteatery", name: "The Anteatery", periods: weekday)]
        #expect(
            MealActivityAutoStart.pick(
                locations: locations,
                nowMinutes: 830,
                alreadyTracking: true,
                autoEnabled: true
            ) == nil
        )
        #expect(
            MealActivityAutoStart.pick(
                locations: locations,
                nowMinutes: 830,
                alreadyTracking: false,
                autoEnabled: false
            ) == nil
        )
    }

    @Test func brunchMapsOntoLiveWindow() {
        let brunchDay = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        // Brunch ends 840 → auto from 795. Sit at 800.
        let pick = MealActivityAutoStart.pick(
            locations: [hall(id: "brandywine", name: "Brandywine", periods: brunchDay)],
            nowMinutes: 800,
            alreadyTracking: false,
            autoEnabled: true
        )
        #expect(pick?.livePeriodName == "Brunch")
    }

    @Test func prefersSoonestEndingHall() {
        let anteatery = hall(
            id: "anteatery",
            name: "The Anteatery",
            periods: [
                MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 900),
            ]
        )
        let brandy = hall(
            id: "brandywine",
            name: "Brandywine",
            periods: [
                MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
            ]
        )
        // 830 is inside both wrap-ups; brandy ends sooner.
        let pick = MealActivityAutoStart.pick(
            locations: [anteatery, brandy],
            nowMinutes: 830,
            alreadyTracking: false,
            autoEnabled: true
        )
        #expect(pick?.hallID == "brandywine")
    }

    @Test func wrapUpAimMinutesAreEndMinus45() {
        let aims = MealActivityAutoStart.wrapUpAimMinutes(
            locations: [hall(id: "anteatery", name: "The Anteatery", periods: weekday)]
        )
        #expect(aims.contains(630 - 45))
        #expect(aims.contains(870 - 45))
        #expect(aims.contains(1200 - 45))
    }

    @Test func mealOpenAimMinutesAreStartTimes() {
        let brunchWeekend = [
            MealPeriodWindow(name: "Brunch", startMinutes: 10 * 60, endMinutes: 14 * 60),
            MealPeriodWindow(name: "Dinner", startMinutes: 16 * 60, endMinutes: 20 * 60),
        ]
        let aims = MealActivityAutoStart.mealOpenAimMinutes(
            locations: [
                hall(id: "anteatery", name: "The Anteatery", periods: weekday),
                hall(id: "brandywine", name: "Brandywine", periods: brunchWeekend),
            ]
        )
        #expect(aims == [435, 600, 660, 960, 990])
    }
}
