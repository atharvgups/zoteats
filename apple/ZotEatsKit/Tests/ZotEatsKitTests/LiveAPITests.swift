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

    /// Guards the dogfood bugs we keep fixing: no raw 404s, no allergen
    /// "not available" chips, Breakfast/Lunch/Dinner pills only, and 24h hours copy.
    @Test func eatAndCampusDogfoodInvariants() async throws {
        let dining = DiningService()
        let campus = CampusService()

        for location in await dining.locations() {
            let primary = DiningService.primaryPeriods(from: location.availablePeriods)
            #expect(primary == ["Breakfast", "Lunch", "Dinner"] || primary.allSatisfy {
                ["Breakfast", "Lunch", "Dinner"].contains($0)
            })
            #expect(!primary.contains(where: { $0.localizedCaseInsensitiveContains("Brunch") }))
            #expect(!primary.contains(where: { $0.localizedCaseInsensitiveContains("All Day") }))

            for period in primary {
                let menu = try await dining.menu(for: location.id, period: period)
                let allergens = menu.stations.flatMap(\.items).flatMap(\.allergens)
                #expect(!allergens.contains(where: {
                    $0.localizedCaseInsensitiveContains("not available")
                        || $0.localizedCaseInsensitiveContains("complete allergen")
                }))
            }
        }

        let unpublished = try await dining.menu(for: "anteatery", period: "Lunch", date: "2099-01-01")
        let unpublishedItems = unpublished.stations.flatMap(\.items)
        #expect(unpublishedItems.isEmpty)

        let places = try await campus.places()
        #expect(!places.contains {
            let hours = $0.todayHours ?? ""
            let compact = hours.replacingOccurrences(of: " ", with: "")
            return compact.contains("12:00AM–12:00AM") || compact.contains("12:00AM-12:00AM")
        })
        // At least one venue should surface the friendly all-day wording when applicable.
        // Soft-check: if any place claims 24h, it must use our label.
        for place in places where (place.todayHours ?? "").localizedCaseInsensitiveContains("24") {
            #expect((place.todayHours ?? "").localizedCaseInsensitiveContains("Open 24 hours"))
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
