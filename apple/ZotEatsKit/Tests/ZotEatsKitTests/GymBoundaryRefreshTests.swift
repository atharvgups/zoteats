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
}
