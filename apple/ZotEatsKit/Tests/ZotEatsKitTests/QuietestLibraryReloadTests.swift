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

    @Test func openArmsWaitzCloseBoundary() {
        // Mon 10 AM — Waitz says close at noon; must arm noon (not only midnight).
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
        let noon = 12 * 60
        let boundaries = QuietestLibraryReload.boundaries(
            now: now,
            anyLibraryOpen: true,
            closeMinutes: [noon]
        )
        let noonDate = UCITime.date(
            forMinutes: noon,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(boundaries.contains(noonDate))
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
    }

    @Test func openWaitzCloseNearBeatsCadence() {
        // Mon 11:55 AM — Waitz close at noon beats 10m open cadence.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:55:00Z")!
        let reload = QuietestLibraryReload.nextReload(
            now: now,
            anyLibraryOpen: true,
            closeMinutes: [12 * 60]
        )
        let noon = UCITime.date(
            forMinutes: 12 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(reload == noon.addingTimeInterval(2))
        #expect(reload < now.addingTimeInterval(10 * 60))
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

    @Test func waitzClosedUntilArmsParsedReopen() {
        // Saturday 10 AM PDT — hardcoded probes already passed; noon from Waitz must be armed.
        let now = ISO8601DateFormatter().date(from: "2026-07-11T17:00:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let noon = 12 * 60
        let boundaries = QuietestLibraryReload.boundaries(
            now: now,
            anyLibraryOpen: false,
            reopenMinutes: [noon]
        )
        let noonDate = UCITime.date(forMinutes: noon, nowMinutes: nowMinutes, now: now)
        #expect(boundaries.contains(noonDate))
        for minutes in QuietestLibraryReload.morningOpenMinutes {
            #expect(boundaries.contains(
                UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            ))
        }
    }

    @Test func waitzReopenNearBeatsClosedCadence() {
        // Monday 11:50 AM — Waitz says noon; must beat 20m closed cadence.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:50:00Z")!
        let reload = QuietestLibraryReload.nextReload(
            now: now,
            anyLibraryOpen: false,
            reopenMinutes: [12 * 60]
        )
        let noon = UCITime.date(
            forMinutes: 12 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(reload == noon.addingTimeInterval(2))
    }

    @Test func reopenMinutesFromLibraryPool() {
        let langson = BusynessPoint(
            id: 1,
            name: "Langson Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: nil,
            level: .unknown,
            isOpen: false,
            hoursSummary: "Closed until 8:00am",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
        let arc = BusynessPoint(
            id: 2,
            name: "ARC",
            category: "Recreation",
            count: nil,
            capacity: nil,
            percent: nil,
            level: .unknown,
            isOpen: false,
            hoursSummary: "Closed until 12:00pm",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
        #expect(QuietestLibraryReload.reopenMinutes(from: [langson, arc]) == [8 * 60])
        #expect(QuietestLibraryReload.reopenMinutes(from: [arc]) == [12 * 60])
    }

    @Test func closeMinutesFromOpenLibraryRanges() {
        let open = BusynessPoint(
            id: 1,
            name: "Langson Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 12,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "8:00am-10:00pm",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
        let closed = BusynessPoint(
            id: 2,
            name: "Science Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 0,
            level: .unknown,
            isOpen: false,
            hoursSummary: "8:00am-11:00pm",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
        #expect(QuietestLibraryReload.closeMinutes(from: [open, closed], nowMinutes: 12 * 60) == [22 * 60])
        #expect(QuietestLibraryReload.closeMinutes(from: [closed], nowMinutes: 12 * 60) == [])
    }

    @Test("Closed-until stale isOpen excluded from closeMinutes")
    func closeMinutesExcludesClosedUntilStaleOpen() {
        let stale = BusynessPoint(
            id: 1,
            name: "Langson Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 12,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "Closed until 8:00am",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
        #expect(QuietestLibraryReload.closeMinutes(from: [stale], nowMinutes: 6 * 60) == [])
    }
}
