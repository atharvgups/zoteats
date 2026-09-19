import Foundation
import Testing
@testable import ZotEatsKit

@Suite("GymSchedule — Summer campusrec")
struct GymScheduleTests {
    @Test("Weekday open/close match Summer ARC hours")
    func weekdayHours() {
        #expect(ArcIdleCopy.todayOpenMinutes(weekday: "Thursday") == 6 * 60)
        #expect(ArcIdleCopy.todayCloseMinutes(weekday: "Thursday") == 22 * 60)
        #expect(GymService.formatHour(6) == "6:00 AM")
        #expect(GymService.formatHour(22) == "10:00 PM")
    }

    @Test("Weekend open/close match Summer ARC hours")
    func weekendHours() {
        #expect(ArcIdleCopy.todayOpenMinutes(weekday: "Saturday") == 8 * 60)
        #expect(ArcIdleCopy.todayCloseMinutes(weekday: "Saturday") == 20 * 60)
        #expect(ArcIdleCopy.todayOpenMinutes(weekday: "Sunday") == 8 * 60)
        #expect(ArcIdleCopy.todayCloseMinutes(weekday: "Sunday") == 20 * 60)
        #expect(GymService.formatHour(20) == "8:00 PM")
    }

    @Test("After weekday close boundary is next open")
    func afterWeekdayClose() {
        // Thursday 10:30 PM Pacific.
        let late = ISO8601DateFormatter().date(from: "2026-07-10T05:30:00Z")!
        let boundary = GymService.nextScheduleBoundary(now: late)
        let minutes = PacificTime.nowMinutes(now: late)
        let expected = UCITime.date(forMinutes: 6 * 60, nowMinutes: minutes, now: late)
        #expect(boundary == expected)
    }
}
