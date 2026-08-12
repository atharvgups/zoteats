import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuHallPick")
struct TodaysMenuHallPickTests {
    private let anteateryDay = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    /// Brandywine dinner opens earlier than Anteatery in this fixture.
    private let brandywineDay = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 960, endMinutes: 1200),
    ]

    private func hall(
        id: String,
        name: String,
        periods: [MealPeriodWindow]
    ) -> DiningLocation {
        DiningLocation(
            id: id,
            name: name,
            area: HallDirectory.area(for: id),
            openNow: false,
            todayHours: nil,
            availablePeriods: periods.map(\.name),
            periods: periods,
            hoursApproximate: true
        )
    }

    @Test func prefersHallServingNowOverAPIOrder() {
        let closedUntilDinner = hall(
            id: "anteatery",
            name: "The Anteatery",
            periods: [
                MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
            ]
        )
        let openSecond = hall(id: "brandywine", name: "Brandywine", periods: brandywineDay)
        // 700 = Brandywine lunch; Anteatery only has Dinner later.
        let pick = TodaysMenuHallPick.auto(
            from: [closedUntilDinner, openSecond],
            nowMinutes: 700
        )
        #expect(pick?.id == "brandywine")
    }

    @Test func betweenMealsPicksSoonestOpeningNotAPIFirst() {
        let anteatery = hall(id: "anteatery", name: "The Anteatery", periods: anteateryDay)
        let brandywine = hall(id: "brandywine", name: "Brandywine", periods: brandywineDay)
        // 900 = between lunch and dinner; Brandywine dinner @ 960, Anteatery @ 990.
        let pick = TodaysMenuHallPick.auto(
            from: [anteatery, brandywine],
            nowMinutes: 900
        )
        #expect(pick?.id == "brandywine")
    }

    @Test func afterHoursFallsBackToAPIFirst() {
        let anteatery = hall(id: "anteatery", name: "The Anteatery", periods: anteateryDay)
        let brandywine = hall(id: "brandywine", name: "Brandywine", periods: brandywineDay)
        let pick = TodaysMenuHallPick.auto(
            from: [anteatery, brandywine],
            nowMinutes: 1300
        )
        #expect(pick?.id == "anteatery")
    }

    @Test func emptyLocationsReturnsNil() {
        #expect(TodaysMenuHallPick.auto(from: [], nowMinutes: 700) == nil)
    }

    @Test func servingBeatsSoonerUpcomingElsewhere() {
        // Anteatery still in lunch; Brandywine already closed until dinner.
        let anteatery = hall(id: "anteatery", name: "The Anteatery", periods: anteateryDay)
        let brandywineClosedLunch = hall(
            id: "brandywine",
            name: "Brandywine",
            periods: [
                MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
                MealPeriodWindow(name: "Dinner", startMinutes: 960, endMinutes: 1200),
            ]
        )
        let pick = TodaysMenuHallPick.auto(
            from: [brandywineClosedLunch, anteatery],
            nowMinutes: 700
        )
        #expect(pick?.id == "anteatery")
    }
}
