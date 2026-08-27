import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatBoundaryRefresh")
struct EatBoundaryRefreshTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]

    @Test func includesMealOpenCloseAndMidnight() {
        // Thursday 2026-07-09 12:00 PDT — Lunch open, closes at 2:30 PM.
        let noon = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: noon)
        let dates = EatBoundaryRefresh.boundaries(
            hallPeriods: [day],
            nowMinutes: nowMinutes,
            now: noon
        )
        #expect(dates.contains(UCITime.nextIrvineMidnight(now: noon)))
        #expect(dates.contains(UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: noon)))
        #expect(dates.contains(UCITime.date(forMinutes: 990, nowMinutes: nowMinutes, now: noon)))
        // Auto-start: Lunch ends 870 → 870 - 45 = 825 (1:45 PM).
        #expect(dates.contains(UCITime.date(forMinutes: 825, nowMinutes: nowMinutes, now: noon)))
    }

    @Test func nextFirePrefersSoonestCloseOverCap() {
        // 2:20 PM PDT — Lunch closes in 10m (inside 15m cap).
        let twoTwenty = ISO8601DateFormatter().date(from: "2026-07-09T21:20:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: twoTwenty)
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: [day],
            nowMinutes: nowMinutes,
            now: twoTwenty
        )
        let lunchClose = UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: twoTwenty)
        #expect(fire == lunchClose.addingTimeInterval(2))
    }

    @Test func brunchMapsAutoStartOntoLiveWindow() {
        let brunchDay = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let midBrunch = ISO8601DateFormatter().date(from: "2026-07-11T18:00:00Z")! // Sat 11 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: midBrunch)
        let dates = EatBoundaryRefresh.boundaries(
            hallPeriods: [brunchDay],
            nowMinutes: nowMinutes,
            now: midBrunch
        )
        // Brunch ends 840 → auto-start at 795.
        #expect(dates.contains(UCITime.date(forMinutes: 795, nowMinutes: nowMinutes, now: midBrunch)))
    }

    @Test func includesEveryHallsWrapUp() {
        let anteatery = [
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        ]
        let brandy = [
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 900),
        ]
        let noon = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: noon)
        let dates = EatBoundaryRefresh.boundaries(
            hallPeriods: [anteatery, brandy],
            nowMinutes: nowMinutes,
            now: noon
        )
        // Anteatery wrap-up 825, Brandywine wrap-up 855 — both scheduled.
        #expect(dates.contains(UCITime.date(forMinutes: 825, nowMinutes: nowMinutes, now: noon)))
        #expect(dates.contains(UCITime.date(forMinutes: 855, nowMinutes: nowMinutes, now: noon)))
    }

    @Test func emptyHallsStillFireAtMidnightOrCap() {
        let noon = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: [],
            nowMinutes: UCITime.nowMinutes(now: noon),
            now: noon
        )
        let midnight = UCITime.nextIrvineMidnight(now: noon)
        let cap = noon.addingTimeInterval(EatBoundaryRefresh.maxInterval)
        #expect(fire == min(midnight.addingTimeInterval(2), cap) || fire == midnight.addingTimeInterval(2) || fire == cap)
        // Midnight is later the same calendar day evening → beyond 15m cap.
        #expect(fire == cap)
    }

    @Test func forceNetworkOnlyOnRolloverOrPublishProbe() {
        #expect(
            !EatBoundaryRefresh.shouldForceNetwork(
                dayRolled: false,
                shouldProbeForPublish: false
            )
        )
        #expect(
            EatBoundaryRefresh.shouldForceNetwork(
                dayRolled: true,
                shouldProbeForPublish: false
            )
        )
        #expect(
            EatBoundaryRefresh.shouldForceNetwork(
                dayRolled: false,
                shouldProbeForPublish: true
            )
        )
    }

    @Test func awaitingBreakfastOnlyArmsLunchPublishProbe() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 11 * 60),
        ]
        // Mon 11:05 AM — 11:15 probe beats 15m cap.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:05:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: [partial],
            nowMinutes: nowMinutes,
            now: now
        )
        let lunchProbe = UCITime.date(
            forMinutes: 11 * 60 + 15,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(fire == lunchProbe.addingTimeInterval(2))
    }

    @Test func emptyBoardArmsLunchPublishProbe() {
        // Mon 10:20 AM — empty [[]] hall; 10:30 probe beats 15m cap.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:20:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: [[]],
            nowMinutes: nowMinutes,
            now: now
        )
        let earlyLunch = UCITime.date(
            forMinutes: 10 * 60 + 30,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(fire == earlyLunch.addingTimeInterval(2))
    }
}

@Suite("MealActivityWrapUpRefresh")
struct MealActivityWrapUpRefreshTests {
    @Test func prefersSoonestWrapUpOverCap() {
        let locations = [
            DiningLocation(
                id: "anteatery",
                name: "The Anteatery",
                area: "UTC",
                openNow: true,
                todayHours: nil,
                availablePeriods: ["Lunch"],
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                ],
                hoursApproximate: false
            ),
        ]
        // Monday 1:40 PM — wrap-up at 1:45 is 5m away.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T20:40:00Z")!
        let fire = MealActivityWrapUpRefresh.nextFire(locations: locations, now: now)
        let wrapUp = UCITime.date(
            forMinutes: 825,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(fire == wrapUp.addingTimeInterval(2))
    }
}
