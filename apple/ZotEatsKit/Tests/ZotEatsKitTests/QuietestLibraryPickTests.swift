import Foundation
import Testing
@testable import ZotEatsKit

@Suite("QuietestLibraryPick")
struct QuietestLibraryPickTests {
    private func point(
        id: Int,
        name: String,
        category: String,
        percent: Int?,
        isOpen: Bool = true,
        subs: [BusynessPoint]? = nil
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: name,
            category: category,
            count: nil,
            capacity: nil,
            percent: percent,
            level: BusynessService.level(forPercent: percent),
            isOpen: isOpen,
            hoursSummary: nil,
            updatedAt: Date(),
            subLocations: subs
        )
    }

    private func zone(id: Int, _ name: String, percent: Int, isOpen: Bool = true) -> BusynessPoint {
        point(id: id, name: name, category: "Library", percent: percent, isOpen: isOpen)
    }

    @Test func prefersLibraryFloorOverQuieterGym() {
        let arc = point(id: 1, name: "Anteater Recreation Center", category: "Recreation", percent: 5)
        let science = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 40,
            subs: [
                zone(id: 21, "5th Floor - Open Seating", percent: 12),
                zone(id: 22, "Lobby", percent: 1),
            ]
        )
        let pick = QuietestLibraryPick.best(from: [arc, science])
        #expect(pick?.title == "Sci Lib · 5th Floor · Open Seating")
        #expect(pick?.percent == 12)
        #expect(pick?.facilityID == 2)
    }

    @Test func floorBeatsFacilityAverageAndDropsLobby() {
        let science = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 30,
            subs: [
                zone(id: 1, "Lobby", percent: 2),
                zone(id: 2, "5th Floor - Open Seating", percent: 4),
                zone(id: 3, "4th Floor - Loft Study Zone", percent: 18),
            ]
        )
        let pick = QuietestLibraryPick.best(from: [science])
        #expect(pick?.percent == 4)
        #expect(pick?.title.contains("Lobby") != true)
        #expect(pick?.title.contains("5th Floor") == true)
    }

    @Test func closedZonesAreIgnored() {
        let science = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 20,
            subs: [
                zone(id: 1, "5th Floor - Open Seating", percent: 1, isOpen: false),
                zone(id: 2, "4th Floor - Open Seating", percent: 9, isOpen: true),
            ]
        )
        let pick = QuietestLibraryPick.best(from: [science])
        #expect(pick?.percent == 9)
        #expect(pick?.title.contains("4th Floor") == true)
    }

    @Test func allLibrariesClosedReturnsNil() {
        let closed = point(id: 2, name: "Science Library", category: "Library", percent: 10, isOpen: false)
        #expect(QuietestLibraryPick.best(from: [closed]) == nil)
    }

    @Test func fixtureLibrariesPickAScienceOrLangsonFloor() async throws {
        let points = try await BusynessService(http: FixtureHTTP(), now: { Date() }).all()
        let pick = try #require(QuietestLibraryPick.best(from: points))
        #expect(pick.percent >= 0)
        #expect(pick.title.contains("Langson") || pick.title.contains("Sci Lib") || pick.title.contains("Science"))
        #expect(pick.facilityID != nil)
    }
}
