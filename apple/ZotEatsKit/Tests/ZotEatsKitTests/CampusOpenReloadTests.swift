import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusOpenReload")
struct CampusOpenReloadTests {
    @Test func includesIrvineMidnightEvenWhenNoPlaces() {
        // Thursday 2026-07-09, 10 PM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")!
        let boundaries = CampusOpenReload.boundaries(places: [], now: now)
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
        let reload = CampusOpenReload.nextReload(now: now, places: [], maxInterval: 20 * 60)
        // Midnight is ~2h away — 20m cap still wins, but midnight is in the set.
        #expect(reload == now.addingTimeInterval(20 * 60))
        #expect(boundaries.contains { $0 > now })
    }

    @Test func closeBoundaryBeatsCapWhenSoon() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let place = CampusPlace(
            id: "starbucks",
            name: "Starbucks",
            category: "Coffee & Cafés",
            openNow: true,
            todayHours: "7:30 AM – 4:00 PM",
            opensAtMinutes: nil,
            closesAtMinutes: 10 * 60 + 5, // 5 minutes after "now" minutes… wait now is 10:00
            opensTomorrowAtMinutes: 7 * 60 + 30
        )
        // nowMinutes at mondayMorning = 10*60. Close at 10:05 → 5 min boundary.
        let reload = CampusOpenReload.nextReload(now: now, places: [place], maxInterval: 20 * 60)
        let expectedClose = UCITime.date(forMinutes: 10 * 60 + 5, nowMinutes: 10 * 60, now: now)
        #expect(reload == expectedClose.addingTimeInterval(2))
    }

    @Test func midnightIncludedAlongsideTomorrowOpen() {
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT
        let place = CampusPlace(
            id: "starbucks",
            name: "Starbucks",
            category: "Coffee & Cafés",
            openNow: false,
            todayHours: nil,
            opensTomorrowAtMinutes: 7 * 60 + 30
        )
        let boundaries = CampusOpenReload.boundaries(places: [place], now: now)
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
        let tomorrowOpen = UCITime.date(
            forMinutes: 7 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(boundaries.contains(tomorrowOpen))
    }

    @Test func openBoundaryBeatsCapWhenSoon() {
        // Mon 6:55 AM PDT — opens at 7:00 (5m), inside 20m in-app/widget cap.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T13:55:00Z")!
        let place = CampusPlace(
            id: "starbucks",
            name: "Starbucks",
            category: "Coffee & Cafés",
            openNow: false,
            todayHours: nil,
            opensAtMinutes: 7 * 60,
            closesAtMinutes: nil,
            opensTomorrowAtMinutes: nil
        )
        let reload = CampusOpenReload.nextReload(now: now, places: [place], maxInterval: 20 * 60)
        let expectedOpen = UCITime.date(
            forMinutes: 7 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(reload == expectedOpen.addingTimeInterval(2))
    }
}
