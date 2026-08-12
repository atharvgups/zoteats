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
            selectedTimedPeriods: day,
            selectedAvailablePeriods: day.map(\.name),
            selectedPill: "Lunch",
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
            selectedTimedPeriods: day,
            selectedAvailablePeriods: day.map(\.name),
            selectedPill: "Lunch",
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
            selectedTimedPeriods: brunchDay,
            selectedAvailablePeriods: brunchDay.map(\.name),
            selectedPill: "Breakfast",
            nowMinutes: nowMinutes,
            now: midBrunch
        )
        // Brunch ends 840 → auto-start at 795.
        #expect(dates.contains(UCITime.date(forMinutes: 795, nowMinutes: nowMinutes, now: midBrunch)))
    }

    @Test func nilPillSkipsAutoStartBoundary() {
        let noon = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: noon)
        let withPill = EatBoundaryRefresh.boundaries(
            hallPeriods: [day],
            selectedTimedPeriods: day,
            selectedAvailablePeriods: day.map(\.name),
            selectedPill: "Lunch",
            nowMinutes: nowMinutes,
            now: noon
        )
        let without = EatBoundaryRefresh.boundaries(
            hallPeriods: [day],
            selectedTimedPeriods: day,
            selectedAvailablePeriods: day.map(\.name),
            selectedPill: nil,
            nowMinutes: nowMinutes,
            now: noon
        )
        let autoAt = UCITime.date(forMinutes: 825, nowMinutes: nowMinutes, now: noon)
        #expect(withPill.contains(autoAt))
        #expect(!without.contains(autoAt))
    }

    @Test func emptyHallsStillFireAtMidnightOrCap() {
        let noon = ISO8601DateFormatter().date(from: "2026-07-09T19:00:00Z")!
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: [],
            selectedTimedPeriods: [],
            selectedAvailablePeriods: [],
            selectedPill: nil,
            nowMinutes: UCITime.nowMinutes(now: noon),
            now: noon
        )
        let midnight = UCITime.nextIrvineMidnight(now: noon)
        let cap = noon.addingTimeInterval(EatBoundaryRefresh.maxInterval)
        #expect(fire == min(midnight.addingTimeInterval(2), cap) || fire == midnight.addingTimeInterval(2) || fire == cap)
        // Midnight is later the same calendar day evening → beyond 15m cap.
        #expect(fire == cap)
    }
}
