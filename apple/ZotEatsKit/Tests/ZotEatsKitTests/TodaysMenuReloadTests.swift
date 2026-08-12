import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuReload")
struct TodaysMenuReloadTests {
    private let evening = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT

    @Test func afterHoursIncludesTomorrowOpenAndMidnight() {
        let nowMinutes = UCITime.nowMinutes(now: evening)
        let boundaries = TodaysMenuReload.boundaries(
            upcomingStartMinutes: nil,
            isAfterHours: true,
            opensTomorrowAtMinutes: 7 * 60 + 15,
            nowMinutes: nowMinutes,
            now: evening
        )
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: evening)))
        let open = UCITime.date(forMinutes: 7 * 60 + 15, nowMinutes: nowMinutes, now: evening)
        #expect(boundaries.contains(open))
    }

    @Test func betweenMealsUsesUpcomingStartNotTomorrow() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T20:00:00Z")! // Mon 1 PM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let boundaries = TodaysMenuReload.boundaries(
            upcomingStartMinutes: 990,
            isAfterHours: false,
            opensTomorrowAtMinutes: 435,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
        #expect(boundaries.contains(UCITime.date(forMinutes: 990, nowMinutes: nowMinutes, now: now)))
        #expect(!boundaries.contains(UCITime.date(forMinutes: 435, nowMinutes: nowMinutes, now: now)))
    }

    @Test func afterHoursWithoutTomorrowKeepsMidnightOnly() {
        let nowMinutes = UCITime.nowMinutes(now: evening)
        let boundaries = TodaysMenuReload.boundaries(
            upcomingStartMinutes: nil,
            isAfterHours: true,
            opensTomorrowAtMinutes: nil,
            nowMinutes: nowMinutes,
            now: evening
        )
        #expect(boundaries == [UCITime.nextIrvineMidnight(now: evening)])
    }
}
