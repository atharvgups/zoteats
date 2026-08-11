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
        #expect(status.opensAtMinutes == nil)
        #expect(status.opensTomorrowAtMinutes == 7 * 60 + 30)
        #expect(status.todayHours?.contains("7:30 AM") == true)
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
        #expect(status.opensAtMinutes == 16 * 60 + 30)
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
