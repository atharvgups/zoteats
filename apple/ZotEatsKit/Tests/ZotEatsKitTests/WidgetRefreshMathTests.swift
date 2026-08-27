import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetRefreshMath")
struct WidgetRefreshMathTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func usesEarliestFutureBoundary() {
        let close = now.addingTimeInterval(5 * 60)
        let later = now.addingTimeInterval(40 * 60)
        let reload = WidgetRefreshMath.nextReload(
            now: now,
            boundaries: [later, close],
            maxInterval: 20 * 60
        )
        #expect(reload == close.addingTimeInterval(2))
    }

    @Test func ignoresPastBoundariesAndCaps() {
        let past = now.addingTimeInterval(-10 * 60)
        let reload = WidgetRefreshMath.nextReload(
            now: now,
            boundaries: [past],
            maxInterval: 20 * 60
        )
        #expect(reload == now.addingTimeInterval(20 * 60))
    }

    @Test func emptyBoundariesUseMaxInterval() {
        let reload = WidgetRefreshMath.nextReload(
            now: now,
            boundaries: [],
            maxInterval: 30 * 60
        )
        #expect(reload == now.addingTimeInterval(30 * 60))
    }

    @Test func boundaryBeyondCapStillCaps() {
        let far = now.addingTimeInterval(2 * 3600)
        let reload = WidgetRefreshMath.nextReload(
            now: now,
            boundaries: [far],
            maxInterval: 20 * 60
        )
        #expect(reload == now.addingTimeInterval(20 * 60))
    }

    @Test func quietestOpenUsesShortCadence() {
        let reload = WidgetRefreshMath.nextQuietestReload(now: now, anyLibraryOpen: true)
        #expect(reload == now.addingTimeInterval(10 * 60))
    }

    @Test func quietestClosedUsesCampusLikeCadence() {
        let reload = WidgetRefreshMath.nextQuietestReload(now: now, anyLibraryOpen: false)
        #expect(reload == now.addingTimeInterval(20 * 60))
    }

    @Test func quietestClosedMidnightBeatsClosedCadence() {
        // Thursday 2026-07-09, 11:50 PM Pacific — midnight is 10m away.
        let late = ISO8601DateFormatter().date(from: "2026-07-10T06:50:00Z")!
        let midnight = UCITime.nextIrvineMidnight(now: late)
        let reload = WidgetRefreshMath.nextQuietestReload(
            now: late,
            anyLibraryOpen: false,
            boundaries: [midnight]
        )
        #expect(reload == midnight.addingTimeInterval(2))
    }

    @Test func quietestBoundaryBeatsOpenCadence() {
        let close = now.addingTimeInterval(3 * 60)
        let reload = WidgetRefreshMath.nextQuietestReload(
            now: now,
            anyLibraryOpen: true,
            boundaries: [close]
        )
        #expect(reload == close.addingTimeInterval(2))
    }
}
