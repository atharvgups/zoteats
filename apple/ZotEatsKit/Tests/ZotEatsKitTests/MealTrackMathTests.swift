import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealTrackMath")
struct MealTrackMathTests {
    /// Thursday 2026-07-09 19:59:45 Pacific (PDT, UTC-7).
    private let nearEightPM: Date = {
        ISO8601DateFormatter().date(from: "2026-07-10T02:59:45Z")!
    }()

    @Test("endsAt is wall-clock meal close, not now + rounded minutes")
    func endsAtMatchesPacificClose() {
        let nowMinutes = UCITime.nowMinutes(now: nearEightPM)
        #expect(nowMinutes == 19 * 60 + 59)

        let ends = MealTrackMath.endsAt(
            endMinutes: 20 * 60,
            nowMinutes: nowMinutes,
            now: nearEightPM
        )
        // Relative math would be ~20:00:45; wall clock is 20:00:00.
        #expect(UCITime.nowMinutes(now: ends) == 20 * 60)
        #expect(PacificTime.todayISO(now: ends) == "2026-07-09")
        let secondsPastMinute = Calendar(identifier: .gregorian)
            .dateComponents(in: PacificTime.timeZone, from: ends)
            .second ?? -1
        #expect(secondsPastMinute == 0)
        #expect(ends.timeIntervalSince(nearEightPM) < 60)
        #expect(ends.timeIntervalSince(nearEightPM) > 0)
    }

    @Test("relative minutesLeft would overshoot the close")
    func relativeOvershoots() {
        let nowMinutes = UCITime.nowMinutes(now: nearEightPM)
        let minutesLeft = 20 * 60 - nowMinutes
        let relative = nearEightPM.addingTimeInterval(TimeInterval(minutesLeft * 60))
        let wall = MealTrackMath.endsAt(
            endMinutes: 20 * 60,
            nowMinutes: nowMinutes,
            now: nearEightPM
        )
        #expect(relative > wall)
        #expect(relative.timeIntervalSince(wall) == 45)
    }

    @Test("shouldAutoStart inside final window")
    func autoStartInsideWindow() {
        #expect(
            MealTrackMath.shouldAutoStart(
                nowMinutes: 19 * 60 + 30,
                startMinutes: 17 * 60,
                endMinutes: 20 * 60,
                alreadyTracking: false,
                autoEnabled: true
            )
        )
    }

    @Test("shouldAutoStart rejects outside window and existing track")
    func autoStartGuards() {
        #expect(
            !MealTrackMath.shouldAutoStart(
                nowMinutes: 18 * 60,
                startMinutes: 17 * 60,
                endMinutes: 20 * 60,
                alreadyTracking: false,
                autoEnabled: true
            )
        )
        #expect(
            !MealTrackMath.shouldAutoStart(
                nowMinutes: 19 * 60 + 30,
                startMinutes: 17 * 60,
                endMinutes: 20 * 60,
                alreadyTracking: true,
                autoEnabled: true
            )
        )
        #expect(
            !MealTrackMath.shouldAutoStart(
                nowMinutes: 19 * 60 + 30,
                startMinutes: 17 * 60,
                endMinutes: 20 * 60,
                alreadyTracking: false,
                autoEnabled: false
            )
        )
        #expect(
            !MealTrackMath.shouldAutoStart(
                nowMinutes: 20 * 60,
                startMinutes: 17 * 60,
                endMinutes: 20 * 60,
                alreadyTracking: false,
                autoEnabled: true
            )
        )
    }

    @Test("key joins hall and period")
    func keyFormat() {
        #expect(MealTrackMath.key(hallID: "anteatery", period: "Dinner") == "anteatery|Dinner")
    }
}
