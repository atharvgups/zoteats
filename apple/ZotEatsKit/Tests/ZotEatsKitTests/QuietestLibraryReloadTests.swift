import Foundation
import Testing
@testable import ZotEatsKit

@Suite("QuietestLibraryReload")
struct QuietestLibraryReloadTests {
    @Test func closedIncludesMidnightAndMorningProbes() {
        // Thursday 2026-07-09, 10 PM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")!
        let boundaries = QuietestLibraryReload.boundaries(now: now, anyLibraryOpen: false)
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
        let nowMinutes = UCITime.nowMinutes(now: now)
        for minutes in QuietestLibraryReload.morningOpenMinutes {
            let probe = UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            #expect(boundaries.contains(probe))
        }
    }

    @Test func openSkipsMorningProbesKeepsMidnight() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let boundaries = QuietestLibraryReload.boundaries(now: now, anyLibraryOpen: true)
        #expect(boundaries == [UCITime.nextIrvineMidnight(now: now)])
    }

    @Test func closedMorningProbeBeatsCadence() {
        // Monday 2026-07-13, 7:50 AM Pacific — 8:00 probe is 10m away.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")!
        let reload = QuietestLibraryReload.nextReload(now: now, anyLibraryOpen: false)
        let eight = UCITime.date(
            forMinutes: 8 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(reload == eight.addingTimeInterval(2))
    }

    @Test func openUsesShortCadence() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reload = QuietestLibraryReload.nextReload(now: now, anyLibraryOpen: true)
        #expect(reload == now.addingTimeInterval(10 * 60))
    }
}
