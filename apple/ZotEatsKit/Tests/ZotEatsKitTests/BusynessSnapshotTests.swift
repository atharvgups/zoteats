import Foundation
import Testing
@testable import ZotEatsKit

@Suite("BusynessSnapshot")
struct BusynessSnapshotTests {
    private func point(
        id: Int = 1,
        percent: Int? = 12,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: "Langson Library",
            category: "Library",
            count: 80,
            capacity: 600,
            percent: percent,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "open",
            updatedAt: updatedAt,
            subLocations: nil
        )
    }

    @Test func ignoresUpdatedAtOnly() {
        let a = point(updatedAt: Date(timeIntervalSince1970: 1))
        let b = point(updatedAt: Date(timeIntervalSince1970: 9_999))
        #expect(a != b)
        #expect(BusynessSnapshot.equalsIgnoringFetchTime(a, b))
    }

    @Test func detectsOccupancyChange() {
        let a = point(percent: 12)
        let b = point(percent: 40)
        #expect(!BusynessSnapshot.equalsIgnoringFetchTime(a, b))
    }

    @Test func comparesNestedFloorsIgnoringTimestamps() {
        let floorA = BusynessPoint(
            id: 11,
            name: "1st Floor",
            category: "Library",
            count: 10,
            capacity: 100,
            percent: 10,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "open",
            updatedAt: Date(timeIntervalSince1970: 1),
            subLocations: nil
        )
        let floorB = BusynessPoint(
            id: 11,
            name: "1st Floor",
            category: "Library",
            count: 10,
            capacity: 100,
            percent: 10,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "open",
            updatedAt: Date(timeIntervalSince1970: 2),
            subLocations: nil
        )
        let parentA = BusynessPoint(
            id: 1,
            name: "Langson Library",
            category: "Library",
            count: 80,
            capacity: 600,
            percent: 12,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "open",
            updatedAt: Date(timeIntervalSince1970: 1),
            subLocations: [floorA]
        )
        let parentB = BusynessPoint(
            id: 1,
            name: "Langson Library",
            category: "Library",
            count: 80,
            capacity: 600,
            percent: 12,
            level: .notBusy,
            isOpen: true,
            hoursSummary: "open",
            updatedAt: Date(timeIntervalSince1970: 99),
            subLocations: [floorB]
        )
        #expect(BusynessSnapshot.equalsIgnoringFetchTime([parentA], [parentB]))
    }
}
