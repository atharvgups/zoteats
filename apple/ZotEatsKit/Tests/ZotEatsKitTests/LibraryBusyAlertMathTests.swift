import Foundation
import Testing
@testable import ZotEatsKit

@Suite("LibraryBusyAlertMath")
struct LibraryBusyAlertMathTests {
    private func point(
        id: Int,
        name: String,
        category: String,
        percent: Int?,
        isOpen: Bool = true,
        source: BusynessSource = .live
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
            subLocations: nil,
            source: source
        )
    }

    @Test func firesOnLiveBusyLibrary() {
        let langson = point(id: 1, name: "Langson", category: "Library", percent: 82)
        let spikes = LibraryBusyAlertMath.spikes(facilities: [langson], alreadyNotifiedIDs: [])
        #expect(spikes.map(\.id) == [1])
    }

    @Test func skipsGuessedTypicalPercent() {
        let langson = point(
            id: 1, name: "Langson", category: "Library", percent: 90, source: .typical
        )
        #expect(LibraryBusyAlertMath.spikes(facilities: [langson], alreadyNotifiedIDs: []).isEmpty)
    }

    @Test func skipsGymAndQuietLibraries() {
        let gym = point(id: 2, name: "ARC", category: "Recreation", percent: 99)
        let quiet = point(id: 3, name: "Science", category: "Library", percent: 20)
        let closed = point(id: 4, name: "Langson", category: "Library", percent: 90, isOpen: false)
        let noPercent = point(id: 5, name: "Gateway", category: "Library", percent: nil)
        #expect(
            LibraryBusyAlertMath.spikes(
                facilities: [gym, quiet, closed, noPercent],
                alreadyNotifiedIDs: []
            ).isEmpty
        )
    }

    @Test func skipsAlreadyNotifiedToday() {
        let langson = point(id: 1, name: "Langson", category: "Library", percent: 80)
        #expect(
            LibraryBusyAlertMath.spikes(facilities: [langson], alreadyNotifiedIDs: [1]).isEmpty
        )
    }
}
