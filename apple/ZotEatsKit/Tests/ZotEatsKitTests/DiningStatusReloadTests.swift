import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusReload")
struct DiningStatusReloadTests {
    @Test func closedTipIncludesMorningProbes() {
        // Monday 2026-07-13, 7:50 AM Pacific — 8:00 probe is 10m away.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")!
        let boundaries = DiningStatusReload.boundaries(
            now: now,
            countdownEnds: [],
            librariesClosed: true
        )
        let eight = UCITime.date(
            forMinutes: 8 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(boundaries.contains(eight))
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))

        let reload = DiningStatusReload.nextReload(
            now: now,
            countdownEnds: [],
            librariesClosed: true
        )
        #expect(reload == eight.addingTimeInterval(2))
    }

    @Test func openTipSkipsMorningProbesKeepsMidnight() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let boundaries = DiningStatusReload.boundaries(
            now: now,
            countdownEnds: [],
            librariesClosed: false
        )
        #expect(boundaries == [UCITime.nextIrvineMidnight(now: now)])
    }

    @Test func soonHallCloseBeatsMorningProbe() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")! // Mon 7:50 AM PDT
        let hallClose = now.addingTimeInterval(3 * 60)
        let reload = DiningStatusReload.nextReload(
            now: now,
            countdownEnds: [hallClose],
            librariesClosed: true
        )
        #expect(reload == hallClose.addingTimeInterval(2))
    }
}
