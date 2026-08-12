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
        updatedAt: Date = Date(),
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
            updatedAt: updatedAt,
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

    @Test("Closed-until stale isOpen is not quietest")
    func closedUntilStaleOpenExcluded() {
        let stale = BusynessPoint(
            id: 2,
            name: "Science Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 5,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "Closed until 8:00am",
            updatedAt: Date(),
            subLocations: nil
        )
        #expect(QuietestLibraryPick.best(from: [stale], nowMinutes: 6 * 60) == nil)
    }

    @Test("Past-range stale isOpen is not quietest")
    func pastRangeStaleOpenExcluded() {
        let stale = BusynessPoint(
            id: 2,
            name: "Langson Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 8,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "8:00am-12:00pm",
            updatedAt: Date(),
            subLocations: nil
        )
        #expect(QuietestLibraryPick.best(from: [stale], nowMinutes: 14 * 60) == nil)
    }

    @Test func pickCarriesWinningZoneUpdatedAt() {
        let zoneStamp = Date(timeIntervalSince1970: 1_720_000_000)
        let science = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 40,
            updatedAt: zoneStamp.addingTimeInterval(-3600),
            subs: [
                point(
                    id: 21,
                    name: "5th Floor - Open Seating",
                    category: "Library",
                    percent: 12,
                    updatedAt: zoneStamp
                ),
                point(
                    id: 22,
                    name: "Lobby",
                    category: "Library",
                    percent: 1,
                    updatedAt: zoneStamp.addingTimeInterval(-10)
                ),
            ]
        )
        // Lobby is dropped by floor grouping; 5th Floor Open Seating wins at 12%.
        let pick = QuietestLibraryPick.best(from: [science])
        #expect(pick?.percent == 12)
        #expect(pick?.updatedAt == zoneStamp)
    }

    @Test func fixtureLibrariesPickAScienceOrLangsonFloor() async throws {
        let points = try await BusynessService(http: FixtureHTTP(), now: { Date() }).all()
        let pick = try #require(QuietestLibraryPick.best(from: points))
        #expect(pick.percent >= 0)
        #expect(pick.title.contains("Langson") || pick.title.contains("Sci Lib") || pick.title.contains("Science"))
        #expect(pick.facilityID != nil)
    }
}
