import Foundation
import Testing
@testable import ZotEatsKit

/// The captured fixtures' active schedule window covers July 2026.
/// Monday 2026-07-13, 10:00 AM Pacific (17:00 UTC).
private let mondayMorning = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
/// Sunday 2026-07-12, 10:00 AM Pacific.
private let sundayMorning = ISO8601DateFormatter().date(from: "2026-07-12T17:00:00Z")!

@Suite("CampusService (fixtures)")
struct CampusServiceTests {
    @Test func listsRetailPlacesExcludingCommons() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let places = try await service.places()
        #expect(!places.isEmpty)
        #expect(!places.contains { $0.id == "the-anteatery" || $0.id == "brandywine" })
        #expect(places.contains { $0.name.contains("Starbucks") })
        #expect(places.contains { $0.name.contains("Panda Express") })
    }

    @Test func categorization() {
        #expect(CampusService.categorize("Starbucks @ Student Center") == "Coffee & Cafés")
        #expect(CampusService.categorize("Zot N Go Express @ Side Door") == "Markets")
        #expect(CampusService.categorize("Panda Express @ West Food Court") == "Food Courts")
        #expect(CampusService.categorize("Anthill Pub") == "Restaurants & Pubs")
        #expect(CampusService.categorize("Jamba @ East Food Court") == "Coffee & Cafés")
    }

    @Test func weekdayHoursResolveFromActiveSchedule() async throws {
        // The July special schedule has Starbucks open Mo-Fr 07:30-16:00, weekends off.
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let starbucks = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(starbucks != nil)
        #expect(starbucks?.openNow == true) // Monday 10 AM within 07:30-16:00
        #expect(starbucks?.todayHours?.contains("7:30 AM") == true)
    }

    @Test func weekendOffMeansClosedWithNoHours() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { sundayMorning })
        let starbucks = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(starbucks?.openNow == false)
        #expect(starbucks?.todayHours == nil)
    }

    @Test func openingHoursRuleParsing() {
        // First matching rule wins; later contradictory rules are ignored.
        let hours = "Mo-Fr 07:30-16:00; Sa off; Sa 07:30-16:00; Su off; Su 07:30-16:00"
        #expect(CampusService.window(from: hours, weekday: "Wednesday") == .init(start: 450, end: 960))
        #expect(CampusService.window(from: hours, weekday: "Saturday") == nil)
        #expect(CampusService.window(from: hours, weekday: "Sunday") == nil)
        #expect(CampusService.window(from: "Mo-Su off", weekday: "Monday") == nil)
        #expect(CampusService.window(from: "Mo,We,Fr 09:00-14:00", weekday: "Friday") == .init(start: 540, end: 840))
        #expect(CampusService.window(from: "Mo,We,Fr 09:00-14:00", weekday: "Tuesday") == nil)
    }

    @Test func publishedMenuMapsDietaryTagsAndAllergens() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let stations = try await service.menu(for: "halal-shack", date: "2026-07-13")
        #expect(!stations.isEmpty)
        let items = stations.flatMap(\.items)
        #expect(!items.isEmpty)
        #expect(items.contains { $0.calories != nil })
        // The fixture's Scrambled Eggs carries Gluten-Free(78)/Vegetarian(99)/Kosher(87)/Halal(133) + Eggs allergen.
        let eggs = items.first { $0.name == "Scrambled Eggs" }
        #expect(eggs != nil)
        #expect(eggs?.allergens.contains("Eggs") == true)
        #expect(eggs?.dietaryTags.contains("Halal") == true)
        #expect(eggs?.dietaryTags.contains("Vegetarian") == true)
    }

    @Test func networkFailurePropagates() async {
        let service = CampusService(http: FailingHTTP(), now: { mondayMorning })
        await #expect(throws: (any Error).self) {
            _ = try await service.places()
        }
    }
}
