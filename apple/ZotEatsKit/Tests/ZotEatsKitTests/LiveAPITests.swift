import Foundation
import Testing
@testable import ZotEatsKit

/// Opt-in smoke tests against the real UCI endpoints.
/// Run with: ZOTEATS_LIVE_TESTS=1 swift test --filter LiveAPI
@Suite("LiveAPI", .enabled(if: ProcessInfo.processInfo.environment["ZOTEATS_LIVE_TESTS"] == "1"))
struct LiveAPITests {
    @Test func diningLocationsAndMenuFromLiveAPI() async throws {
        let service = DiningService()
        let locations = await service.locations()
        #expect(locations.count == 2)

        if let hall = locations.first(where: { !$0.availablePeriods.isEmpty }) {
            let menu = try await service.menu(for: hall.id, period: hall.availablePeriods[0])
            #expect(!menu.stations.isEmpty)
            let items = menu.stations.flatMap(\.items)
            #expect(items.contains { $0.calories != nil })
        }
    }

    @Test func busynessFromLiveFeed() async throws {
        let points = try await BusynessService().all()
        #expect(!points.isEmpty)
        #expect(points.contains { $0.category == "Library" })
    }

    @Test func gymStatusFromLiveData() async {
        let status = await GymService().status()
        #expect(status.todayHours != nil)
        #expect(status.weekHours.count == 7)
    }

    @Test func campusRetailFromLiveHub() async throws {
        let places = try await CampusService().places()
        #expect(places.count >= 10)
        #expect(places.contains { $0.name.contains("Starbucks") })
        #expect(!places.contains { $0.id == "the-anteatery" })
    }
}
