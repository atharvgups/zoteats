import Foundation
import Testing
@testable import ZotEatsKit

@Suite("GymBoundaryRefresh")
struct GymBoundaryRefreshTests {
    @Test func prefersSoonCloseOverCap() {
        // Weekday fixture close is 10 PM; sit 5 minutes before.
        let late = ISO8601DateFormatter().date(from: "2026-07-09T04:55:00Z")! // Thu 9:55 PM PDT
        let boundary = GymService.nextScheduleBoundary(now: late)
        let fire = GymBoundaryRefresh.nextFire(now: late)
        #expect(boundary != nil)
        #expect(fire == boundary!.addingTimeInterval(2))
    }

    @Test func capsWhenBoundaryFar() {
        // Mid-morning weekday — close is many hours away; 15m cap wins.
        let morning = ISO8601DateFormatter().date(from: "2026-07-09T17:00:00Z")! // Thu 10 AM PDT
        let fire = GymBoundaryRefresh.nextFire(now: morning)
        #expect(fire == morning.addingTimeInterval(GymBoundaryRefresh.maxInterval))
    }

    @Test func emptyBoundariesStillCap() {
        // Use a far-future artificial max when schedule has no near boundary —
        // nextFire always returns a date (never nil).
        let morning = ISO8601DateFormatter().date(from: "2026-07-09T17:00:00Z")!
        let fire = GymBoundaryRefresh.nextFire(now: morning, maxInterval: 15 * 60)
        #expect(fire > morning)
        #expect(fire <= morning.addingTimeInterval(15 * 60))
    }

    @Test func includesIrvineMidnightEvenAfterClose() {
        // Thu 10:30 PM PDT — ARC already closed; tomorrow open is hours away.
        let afterClose = ISO8601DateFormatter().date(from: "2026-07-09T05:30:00Z")!
        let boundaries = GymBoundaryRefresh.boundaries(now: afterClose)
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: afterClose)))
    }

    @Test func midnightBeatsCapWhenNear() {
        // ~10 minutes before Irvine midnight — StandBy must flip “Opens tomorrow”.
        let beforeMidnight = ISO8601DateFormatter().date(from: "2026-07-10T06:50:00Z")! // Thu 11:50 PM PDT
        let midnight = UCITime.nextIrvineMidnight(now: beforeMidnight)
        let fire = GymBoundaryRefresh.nextFire(now: beforeMidnight)
        #expect(fire == midnight.addingTimeInterval(2))
        #expect(fire < beforeMidnight.addingTimeInterval(GymBoundaryRefresh.maxInterval))
    }

    @Test func waitzClosedUntilBeatsFifteenMinuteCap() {
        // Mon 11:50 AM — schedule open was 6 AM; Waitz says noon.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:50:00Z")!
        let noon = 12 * 60
        let fire = GymBoundaryRefresh.nextFire(now: now, reopenMinutes: noon)
        let expected = UCITime.date(
            forMinutes: noon,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(fire == expected.addingTimeInterval(2))
        #expect(fire < now.addingTimeInterval(GymBoundaryRefresh.maxInterval))
    }

    @Test func waitzClosedUntilInBoundaries() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let boundaries = GymBoundaryRefresh.boundaries(now: now, reopenMinutes: 12 * 60)
        let noon = UCITime.date(
            forMinutes: 12 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(boundaries.contains(noon))
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
    }

    @Test func waitzLiveCloseBeatsFifteenMinuteCap() {
        // Mon 11:50 AM — Waitz live range closes at noon (holiday early close).
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:50:00Z")!
        let noon = 12 * 60
        let fire = GymBoundaryRefresh.nextFire(now: now, closeMinutes: noon)
        let expected = UCITime.date(
            forMinutes: noon,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(fire == expected.addingTimeInterval(2))
        #expect(fire < now.addingTimeInterval(GymBoundaryRefresh.maxInterval))
    }
}
