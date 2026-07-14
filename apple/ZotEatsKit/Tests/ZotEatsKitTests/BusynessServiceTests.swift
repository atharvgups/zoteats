import Foundation
import Testing
@testable import ZotEatsKit

private let fixtureNow = ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")!

@Suite("BusynessService (fixtures)")
struct BusynessServiceTests {
    private func service() -> BusynessService {
        BusynessService(http: FixtureHTTP(), now: { fixtureNow })
    }

    @Test func normalizesLiveFeed() async throws {
        let points = try await service().all()
        #expect(!points.isEmpty)

        let langson = points.first { $0.name.contains("Langson") }
        #expect(langson != nil)
        #expect(langson?.category == "Library")
        #expect(langson?.count != nil)
        #expect(langson?.capacity != nil)
        if let percent = langson?.percent {
            #expect((0...100).contains(percent))
        }
        #expect(langson?.updatedAt == fixtureNow)
    }

    @Test func subLocationsAreNormalizedRecursively() async throws {
        let points = try await service().all()
        let withSubs = points.first { $0.subLocations?.isEmpty == false }
        #expect(withSubs != nil)
        #expect(withSubs?.subLocations?.allSatisfy { (0...100).contains($0.percent ?? 0) } == true)
    }

    @Test func categorization() {
        #expect(BusynessService.categorize("Langson Library") == "Library")
        #expect(BusynessService.categorize("ARC Fitness Floor") == "Recreation")
        #expect(BusynessService.categorize("The Anteatery") == "Dining")
        #expect(BusynessService.categorize("Student Center") == "Campus")
    }

    @Test func busynessLevels() {
        #expect(BusynessService.level(forPercent: nil) == .unknown)
        #expect(BusynessService.level(forPercent: 20) == .notBusy)
        #expect(BusynessService.level(forPercent: 45) == .notBusy)
        #expect(BusynessService.level(forPercent: 60) == .busy)
        #expect(BusynessService.level(forPercent: 81) == .veryBusy)
    }

    @Test func feedFailurePropagatesAsError() async {
        let service = BusynessService(http: FailingHTTP(), now: { fixtureNow })
        await #expect(throws: (any Error).self) {
            _ = try await service.all()
        }
    }
}

@Suite("GymService")
struct GymServiceTests {
    @Test func fallsBackToMaintainedScheduleWhenFeedIsDown() async {
        // Thursday 12:30 PM Pacific — ARC schedule says open 6 AM to midnight.
        let service = GymService(
            busyness: BusynessService(http: FailingHTTP(), now: { fixtureNow }),
            now: { fixtureNow }
        )
        let status = await service.status()
        #expect(status.name == "Anteater Recreation Center")
        #expect(status.openNow)
        #expect(status.hoursApproximate)
        #expect(status.todayHours == "6:00 AM – 12:00 AM")
        #expect(status.weekHours.count == 7)
        // No live feed -> busyness is the typical-pattern estimate, flagged as such.
        #expect(status.busyness?.source == .typical)
    }

    @Test func usesLiveFeedWhenArcIsTracked() async {
        // The captured Waitz fixture may or may not include the ARC; assert consistency either way.
        let service = GymService(
            busyness: BusynessService(http: FixtureHTTP(), now: { fixtureNow }),
            now: { fixtureNow }
        )
        let status = await service.status()
        if let arc = status.busyness {
            #expect(arc.category == "Recreation" || arc.name.lowercased().contains("arc"))
            #expect(status.hoursApproximate == (arc.hoursSummary == nil))
        } else {
            #expect(status.hoursApproximate)
        }
    }
}
