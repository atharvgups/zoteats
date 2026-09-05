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
            opensTomorrowAtMinutes: nil,
            upcomingWindows: [
                CampusHoursWindow(startMinutes: 7 * 60, endMinutes: 16 * 60),
            ]
        )
        let reload = CampusOpenReload.nextReload(now: now, places: [place], maxInterval: 20 * 60)
        let expectedOpen = UCITime.date(
            forMinutes: 7 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(reload == expectedOpen.addingTimeInterval(2))
    }

    @Test func splitScheduleIncludesLaterReopenBoundary() {
        // Mon 10 AM PDT — morning still open; afternoon reopen must be in the set.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
        let place = CampusPlace(
            id: "zot-n-go",
            name: "Zot n Go",
            category: "Markets",
            openNow: true,
            todayHours: "7:30 AM – 11:00 AM, 4:30 PM – 9:00 PM",
            opensAtMinutes: 16 * 60 + 30,
            closesAtMinutes: 11 * 60,
            upcomingWindows: [
                CampusHoursWindow(startMinutes: 16 * 60 + 30, endMinutes: 21 * 60),
            ],
            tomorrowOpenWindows: [
                CampusHoursWindow(startMinutes: 7 * 60 + 30, endMinutes: 11 * 60),
            ]
        )
        let boundaries = CampusOpenReload.boundaries(places: [place], now: now)
        let afternoon = UCITime.date(
            forMinutes: 16 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(boundaries.contains(afternoon))
    }

    @Test func laterWeekdayOpenBoundaryIncluded() {
        // Friday 5 PM PDT — Sat/Sun closed; Monday 7:30 AM must be in the set.
        let now = ISO8601DateFormatter().date(from: "2026-07-11T00:00:00Z")! // Fri 5 PM PDT
        let place = CampusPlace(
            id: "starbucks",
            name: "Starbucks",
            category: "Coffee & Cafés",
            openNow: false,
            todayHours: nil,
            opensNextAtMinutes: 7 * 60 + 30,
            opensNextDayOffset: 3,
            opensNextWeekday: "Monday",
            nextOpenWindows: [
                CampusHoursWindow(startMinutes: 7 * 60 + 30, endMinutes: 16 * 60),
            ]
        )
        let boundaries = CampusOpenReload.boundaries(places: [place], now: now)
        let mondayOpen = UCITime.date(forMinutes: 7 * 60 + 30, dayOffset: 3, now: now)
        #expect(boundaries.contains(mondayOpen))
    }
}
