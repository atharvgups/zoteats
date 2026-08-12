import Foundation
import Testing
@testable import ZotEatsKit

@Suite("LibraryHoursService")
struct LibraryHoursServiceTests {
    @Test func parsesLibCalClocks() {
        #expect(LibraryHoursService.parseClock("8am") == 8 * 60)
        #expect(LibraryHoursService.parseClock("8:30pm") == 20 * 60 + 30)
        #expect(LibraryHoursService.parseClock("12pm") == 12 * 60)
        #expect(LibraryHoursService.parseClock("12am") == 0)
        #expect(LibraryHoursService.parseClock("open") == nil)
    }

    @Test func prettyRenderedNormalizesDashes() {
        #expect(
            LibraryHoursService.prettyRendered("8am - 8pm")
                == "\(UCITime.format(minutes: 8 * 60)) – \(UCITime.format(minutes: 20 * 60))"
        )
    }

    @Test func fixtureReturnsLangsonAndScience() async throws {
        let hours = try await LibraryHoursService(http: FixtureHTTP()).today()
        #expect(hours.map(\.id) == ["langson", "science"])
        #expect(hours[0].shortName == "Langson")
        #expect(hours[1].shortName == "Science")
        #expect(hours[0].isOpen)
        #expect(hours[0].openMinutes == 8 * 60)
        #expect(hours[0].closeMinutes == 20 * 60)
        #expect(hours[0].rendered.contains("8:00 AM"))
        #expect(hours[0].rendered.contains("8:00 PM"))
    }

    @Test func matchesWaitzFacilityNames() {
        let hours = [
            LibraryBuildingHours(
                id: "langson",
                shortName: "Langson",
                rendered: "8:00 AM – 8:00 PM",
                isOpen: true,
                openMinutes: 8 * 60,
                closeMinutes: 20 * 60
            ),
            LibraryBuildingHours(
                id: "science",
                shortName: "Science",
                rendered: "8:00 AM – 8:00 PM",
                isOpen: true,
                openMinutes: 8 * 60,
                closeMinutes: 20 * 60
            ),
        ]
        #expect(LibraryHoursMatch.buildingID(forFacilityName: "Langson Library") == "langson")
        #expect(LibraryHoursMatch.buildingID(forFacilityName: "Science Library") == "science")
        #expect(LibraryHoursMatch.hours(forFacilityName: "Langson Library", from: hours)?.id == "langson")
        #expect(LibraryHoursMatch.hours(forFacilityName: "ARC", from: hours) == nil)
    }
}

@Suite("CampusMenuEmptyCopy")
struct CampusMenuEmptyCopyTests {
    @Test func hubFlagMeansNotPosted() {
        #expect(CampusMenuEmptyCopy.kind(hasMenuFlag: true, category: "Coffee & Cafés") == .notPosted)
    }

    @Test func foodCourtsEmptyAreNotPosted() {
        #expect(CampusMenuEmptyCopy.kind(hasMenuFlag: false, category: "Food Courts") == .notPosted)
        #expect(CampusMenuEmptyCopy.kind(hasMenuFlag: false, category: "Restaurants & Pubs") == .notPosted)
    }

    @Test func brandCoffeeIsNotPublished() {
        #expect(CampusMenuEmptyCopy.kind(hasMenuFlag: false, category: "Coffee & Cafés") == .notPublished)
        #expect(CampusMenuEmptyCopy.kind(hasMenuFlag: false, category: "Markets") == .notPublished)
    }

    @Test func copyNeverMentionsFakeDishes() {
        let msg = CampusMenuEmptyCopy.message(kind: .notPosted, placeName: "Halal Shack")
        #expect(msg.contains("Halal Shack"))
        #expect(!msg.localizedCaseInsensitiveContains("sample"))
        #expect(!msg.localizedCaseInsensitiveContains("example"))
    }
}
