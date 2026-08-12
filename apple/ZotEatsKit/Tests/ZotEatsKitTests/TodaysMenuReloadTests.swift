import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuReload")
struct TodaysMenuReloadTests {
    private let evening = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT

    private func hall(
        id: String,
        name: String,
        periods: [MealPeriodWindow],
        opensTomorrowAtMinutes: Int? = 435
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
            opensTomorrowAtMinutes: opensTomorrowAtMinutes
        )
    }

    @Test func afterHoursIncludesTomorrowOpenAndMidnight() {
        let nowMinutes = UCITime.nowMinutes(now: evening)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [],
                opensTomorrowAtMinutes: 7 * 60 + 15
            ),
        ]
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: evening
        )
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: evening)))
        let open = UCITime.date(forMinutes: 7 * 60 + 15, nowMinutes: nowMinutes, now: evening)
        #expect(boundaries.contains(open))
    }

    @Test func betweenMealsArmsDinnerOpenForEveryHall() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T20:00:00Z")! // Mon 1 PM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let dinner = MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200)
        let locations = [
            hall(id: "anteatery", name: "The Anteatery", periods: [dinner]),
            hall(id: "brandywine", name: "Brandywine", periods: [dinner]),
        ]
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
        #expect(boundaries.contains(UCITime.date(forMinutes: 990, nowMinutes: nowMinutes, now: now)))
        #expect(boundaries.contains(UCITime.date(forMinutes: 1200, nowMinutes: nowMinutes, now: now)))
        #expect(boundaries.contains(UCITime.date(forMinutes: 435, nowMinutes: nowMinutes, now: now)))
    }

    @Test func siblingHallCloseArmedWhileAnotherIsAutoPick() {
        // Mon noon — Auto may show Anteatery, but Mesa's later lunch close must
        // wake StandBy so Auto can switch when Anteatery ends first.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")! // Mon noon PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                ]
            ),
            hall(
                id: "mesa",
                name: "Mesa Court",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 900),
                ]
            ),
        ]
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now
        )
        let anteateryClose = UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now)
        let mesaClose = UCITime.date(forMinutes: 900, nowMinutes: nowMinutes, now: now)
        #expect(boundaries.contains(anteateryClose))
        #expect(boundaries.contains(mesaClose))
        // Past the 30m StandBy cap so the sibling close is the soonest wake.
        let reload = TodaysMenuReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            maxInterval: 4 * 60 * 60
        )
        #expect(reload == anteateryClose.addingTimeInterval(2))
    }

    @Test func emptyLocationsKeepMidnightOnly() {
        let nowMinutes = UCITime.nowMinutes(now: evening)
        let boundaries = TodaysMenuReload.boundaries(
            locations: [],
            nowMinutes: nowMinutes,
            now: evening
        )
        #expect(boundaries == [UCITime.nextIrvineMidnight(now: evening)])
    }

    @Test func soonestTomorrowOpenAmongHalls() {
        // Just after Irvine midnight — breakfast opens beat the next midnight.
        let afterMidnight = ISO8601DateFormatter().date(from: "2026-07-10T07:05:00Z")! // Fri 12:05 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: afterMidnight)
        let locations = [
            hall(
                id: "brandywine",
                name: "Brandywine",
                periods: [],
                opensTomorrowAtMinutes: 10 * 60
            ),
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [],
                opensTomorrowAtMinutes: 7 * 60 + 15
            ),
        ]
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: afterMidnight
        )
        let early = UCITime.date(
            forMinutes: 7 * 60 + 15,
            nowMinutes: nowMinutes,
            now: afterMidnight
        )
        let late = UCITime.date(
            forMinutes: 10 * 60,
            nowMinutes: nowMinutes,
            now: afterMidnight
        )
        #expect(boundaries.contains(early))
        #expect(boundaries.contains(late))
        let reload = TodaysMenuReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: afterMidnight,
            maxInterval: 12 * 60 * 60
        )
        #expect(reload == early.addingTimeInterval(2))
    }

    @Test func awaitingBreakfastOnlyArmsLunchPublishProbe() {
        // Mon 11:05 AM — Breakfast ended; Dinner not posted → wake at 11:15.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:05:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 11 * 60),
                ]
            ),
        ]
        let lunchProbe = UCITime.date(
            forMinutes: 11 * 60 + 15,
            nowMinutes: nowMinutes,
            now: now
        )
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(boundaries.contains(lunchProbe))
        let reload = TodaysMenuReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            maxInterval: 30 * 60
        )
        #expect(reload == lunchProbe.addingTimeInterval(2))
    }

    @Test func awaitingLunchOnlyArmsDinnerPublishProbe() {
        // Mon 3:05 PM — Lunch done, no Dinner yet → 3:30 probe beats 30m cap.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T22:05:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                ]
            ),
        ]
        let dinnerProbe = UCITime.date(
            forMinutes: 15 * 60 + 30,
            nowMinutes: nowMinutes,
            now: now
        )
        let reload = TodaysMenuReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            maxInterval: 30 * 60
        )
        #expect(reload == dinnerProbe.addingTimeInterval(2))
    }

    @Test func fullBoardDoesNotArmPublishProbes() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:05:00Z")! // Mon 11:05
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                    MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
                ]
            ),
        ]
        let lunchProbe = UCITime.date(
            forMinutes: 11 * 60 + 15,
            nowMinutes: nowMinutes,
            now: now
        )
        let boundaries = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(!boundaries.contains(lunchProbe))
    }
}
