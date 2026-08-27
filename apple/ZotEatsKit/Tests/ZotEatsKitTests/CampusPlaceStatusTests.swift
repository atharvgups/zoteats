import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusPlaceStatus")
struct CampusPlaceStatusTests {
    @Test func openWindowReportsCloseBoundary() {
        let windows = [CampusService.TimeWindow(start: 7 * 60 + 30, end: 16 * 60)]
        let status = CampusPlaceStatus.evaluate(
            todayWindows: windows,
            tomorrowWindows: windows,
            nowMinutes: 10 * 60
        )
        #expect(status.openNow)
        #expect(status.closesAtMinutes == 16 * 60)
        #expect(status.currentOpenStartMinutes == 7 * 60 + 30)
        #expect(status.opensAtMinutes == nil)
        #expect(status.opensTomorrowAtMinutes == 7 * 60 + 30)
        #expect(status.tomorrowHours?.contains("7:30 AM") == true)
        #expect(status.tomorrowHours?.contains("4:00 PM") == true)
    }

    @Test func afterCloseSurfacesTomorrowOpen() {
        let today = [CampusService.TimeWindow(start: 7 * 60 + 30, end: 16 * 60)]
        let tomorrow = [CampusService.TimeWindow(start: 7 * 60 + 30, end: 16 * 60)]
        let status = CampusPlaceStatus.evaluate(
            todayWindows: today,
            tomorrowWindows: tomorrow,
            nowMinutes: 17 * 60
        )
        #expect(!status.openNow)
        #expect(status.closesAtMinutes == nil)
        #expect(status.opensAtMinutes == nil)
        #expect(status.opensTomorrowAtMinutes == 7 * 60 + 30)
        #expect(status.tomorrowHours?.contains("7:30 AM") == true)
        #expect(status.tomorrowHours?.contains("4:00 PM") == true)
    }

    @Test func emptyTomorrowWindowsOmitTomorrowHours() {
        let today = [CampusService.TimeWindow(start: 7 * 60 + 30, end: 16 * 60)]
        let status = CampusPlaceStatus.evaluate(
            todayWindows: today,
            tomorrowWindows: [],
            nowMinutes: 17 * 60
        )
        #expect(status.opensTomorrowAtMinutes == nil)
        #expect(status.tomorrowHours == nil)
    }

    @Test func splitHoursSchedulesLaterReopenWhileOpen() {
        let windows = [
            CampusService.TimeWindow(start: 7 * 60 + 30, end: 11 * 60),
            CampusService.TimeWindow(start: 16 * 60 + 30, end: 21 * 60),
        ]
        let status = CampusPlaceStatus.evaluate(
            todayWindows: windows,
            tomorrowWindows: [],
            nowMinutes: 10 * 60
        )
        #expect(status.openNow)
        #expect(status.closesAtMinutes == 11 * 60)
        #expect(status.currentOpenStartMinutes == 7 * 60 + 30)
        #expect(status.opensAtMinutes == 16 * 60 + 30)
    }

    @Test func closedHasNoCurrentOpenStart() {
        let today = [CampusService.TimeWindow(start: 7 * 60 + 30, end: 16 * 60)]
        let status = CampusPlaceStatus.evaluate(
            todayWindows: today,
            tomorrowWindows: [],
            nowMinutes: 17 * 60
        )
        #expect(!status.openNow)
        #expect(status.currentOpenStartMinutes == nil)
    }
}

@Suite("CampusPlace live open from snapshot windows")
struct CampusPlaceLiveOpenTests {
    private func starbucks(
        openNow: Bool,
        currentStart: Int?,
        closesAt: Int?,
        upcoming: [CampusHoursWindow]
    ) -> CampusPlace {
        CampusPlace(
            id: "starbucks-at-student-center",
            name: "Starbucks @ Student Center",
            category: "Coffee & Cafés",
            openNow: openNow,
            todayHours: "7:30 AM – 4:00 PM",
            currentOpenStartMinutes: currentStart,
            closesAtMinutes: closesAt,
            upcomingWindows: upcoming
        )
    }

    @Test func bakedOpenFlipsClosedAfterWindowEnds() {
        let place = starbucks(
            openNow: true,
            currentStart: 7 * 60 + 30,
            closesAt: 16 * 60,
            upcoming: []
        )
        #expect(place.isOpen(nowMinutes: 15 * 60))
        #expect(!place.isOpen(nowMinutes: 16 * 60))
        #expect(!place.isOpen(nowMinutes: 17 * 60))
    }

    @Test func upcomingWindowFlipsOpenWithoutRefetch() {
        let place = starbucks(
            openNow: false,
            currentStart: nil,
            closesAt: nil,
            upcoming: [CampusHoursWindow(startMinutes: 7 * 60 + 30, endMinutes: 16 * 60)]
        )
        #expect(!place.isOpen(nowMinutes: 7 * 60))
        #expect(place.isOpen(nowMinutes: 8 * 60))
    }

    @Test func twentyFourHourFallsBackToBakedFlag() {
        let place = CampusPlace(
            id: "zot-n-go",
            name: "Zot N Go",
            category: "Markets",
            openNow: true,
            todayHours: "Open 24 hours"
        )
        #expect(place.isOpen(nowMinutes: 3 * 60))
    }
}

@Suite("CampusService — live open state within TTL")
struct CampusServiceLiveOpenTests {
    /// Mutable clock so one TTL-warmed service can cross a close/open boundary.
    private final class Clock: @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    @Test func openFlipsToClosedWithoutWaitingOutTTL() async throws {
        // Monday 10 AM Pacific — Starbucks open until 4 PM on the July special.
        let morning = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
        let afterClose = ISO8601DateFormatter().date(from: "2026-07-13T23:30:00Z")! // 4:30 PM PDT
        let clock = Clock(morning)
        let service = CampusService(http: FixtureHTTP(), cache: TTLCache(), now: { clock.date })

        let open = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(open?.openNow == true)
        #expect(open?.closesAtMinutes == 16 * 60)

        clock.date = afterClose
        let closed = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(closed?.openNow == false)
        #expect(closed?.closesAtMinutes == nil)
        #expect(closed?.opensTomorrowAtMinutes == 7 * 60 + 30)
        #expect(closed?.tomorrowHours?.contains("7:30 AM") == true)
    }

    @Test func closedFlipsToOpenWithoutWaitingOutTTL() async throws {
        let beforeOpen = ISO8601DateFormatter().date(from: "2026-07-13T14:00:00Z")! // 7:00 AM PDT
        let afterOpen = ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z")! // 8:00 AM PDT
        let clock = Clock(beforeOpen)
        let service = CampusService(http: FixtureHTTP(), cache: TTLCache(), now: { clock.date })

        let closed = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(closed?.openNow == false)
        #expect(closed?.opensAtMinutes == 7 * 60 + 30)

        clock.date = afterOpen
        let open = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(open?.openNow == true)
        #expect(open?.closesAtMinutes == 16 * 60)
    }
}
