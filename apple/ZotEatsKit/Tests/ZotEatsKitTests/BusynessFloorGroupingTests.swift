import Foundation
import Testing
@testable import ZotEatsKit

@Suite("BusynessFloorGrouping")
struct BusynessFloorGroupingTests {
    private func zone(
        id: Int,
        _ name: String,
        percent: Int = 10
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: name,
            category: "Library",
            count: nil,
            capacity: nil,
            percent: percent,
            level: BusynessService.level(forPercent: percent),
            isOpen: true,
            hoursSummary: nil,
            updatedAt: Date(),
            subLocations: nil
        )
    }

    @Test func groupsScienceZonesByFloorAndDropsLobby() {
        let floors = BusynessFloorGrouping.floors(from: [
            zone(id: 1, "2nd Floor - Active Study Zone", percent: 9),
            zone(id: 2, "2nd Floor - Grand Reading Room", percent: 9),
            zone(id: 3, "3rd Floor - Mezzanine", percent: 20),
            zone(id: 4, "4th Floor - Loft Study Zone", percent: 6),
            zone(id: 5, "4th Floor - Open Seating", percent: 5),
            zone(id: 6, "5th Floor - Collaboration Zone", percent: 1),
            zone(id: 7, "5th Floor - Open Seating", percent: 6),
            zone(id: 8, "6th Floor - Faculty Graduate Reading Room", percent: 13),
            zone(id: 9, "6th Floor - Open Seating", percent: 6),
            zone(id: 10, "Lobby", percent: 15),
        ])

        #expect(floors.map(\.floorLabel) == [
            "2nd Floor", "3rd Floor", "4th Floor", "5th Floor", "6th Floor",
        ])
        #expect(!floors.contains { $0.floorLabel.localizedCaseInsensitiveContains("Lobby") })
        #expect(floors.first { $0.floorLabel == "2nd Floor" }?.zones.map(\.displayName) == [
            "Active Study Zone", "Grand Reading Room",
        ])
        // Quietest zone first within a floor.
        #expect(floors.first { $0.floorLabel == "4th Floor" }?.zones.map(\.displayName) == [
            "Open Seating", "Loft Study Zone",
        ])
    }

    @Test func groupsLangsonWithoutDuplicateFloorNames() {
        let floors = BusynessFloorGrouping.floors(from: [
            zone(id: 1, "1st Floor", percent: 12),
            zone(id: 2, "2nd Floor - Holden Room", percent: 15),
            zone(id: 3, "2nd Floor - Open Seating", percent: 26),
            zone(id: 4, "3rd Floor - Collaboration Zone", percent: 17),
            zone(id: 5, "3rd Floor - Open Seating", percent: 12),
            zone(id: 6, "4th Floor - Nordstrom Honors Study Room", percent: 12),
            zone(id: 7, "4th Floor - Open Seating", percent: 10),
            zone(id: 8, "Basement", percent: 3),
        ])

        #expect(floors.map(\.floorLabel) == [
            "Basement", "1st Floor", "2nd Floor", "3rd Floor", "4th Floor",
        ])
        #expect(floors.first { $0.floorLabel == "Basement" }?.zones.map(\.displayName) == ["Basement"])
        #expect(floors.first { $0.floorLabel == "1st Floor" }?.zones.map(\.displayName) == ["1st Floor"])
        #expect(floors.first { $0.floorLabel == "3rd Floor" }?.zones.map(\.displayName) == [
            "Open Seating", "Collaboration Zone",
        ])
        #expect(floors.first { $0.floorLabel == "4th Floor" }?.zones.map(\.displayName) == [
            "Open Seating", "Nordstrom Honors Study Room",
        ])
    }

    @Test func parseSplitsFloorPrefix() {
        let parsed = BusynessFloorGrouping.parse("4th Floor - Open Seating")
        #expect(parsed.floorLabel == "4th Floor")
        #expect(parsed.zoneLabel == "Open Seating")
        #expect(parsed.sortIndex == 4)
    }

    @Test func emptyAndNilInput() {
        #expect(BusynessFloorGrouping.floors(from: nil).isEmpty)
        #expect(BusynessFloorGrouping.floors(from: []).isEmpty)
    }

    @Test func fixtureLibrariesGroupCleanly() async throws {
        let points = try await BusynessService(http: FixtureHTTP(), now: { Date() }).all()
        let science = points.first { $0.name.contains("Science") }
        let langson = points.first { $0.name.contains("Langson") }
        #expect(science != nil)
        #expect(langson != nil)

        let scienceFloors = BusynessFloorGrouping.floors(from: science?.subLocations)
        let langsonFloors = BusynessFloorGrouping.floors(from: langson?.subLocations)

        #expect(scienceFloors.map(\.floorLabel) == [
            "2nd Floor", "3rd Floor", "4th Floor", "5th Floor", "6th Floor",
        ])
        #expect(langsonFloors.map(\.floorLabel) == [
            "Basement", "1st Floor", "2nd Floor", "3rd Floor", "4th Floor",
        ])
        #expect(scienceFloors.allSatisfy { floor in
            floor.zones.allSatisfy { !$0.displayName.lowercased().hasPrefix(floor.floorLabel.lowercased() + " -") }
        })
    }
}
