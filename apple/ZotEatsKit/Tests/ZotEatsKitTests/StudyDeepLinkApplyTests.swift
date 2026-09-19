import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyDeepLinkApply")
struct StudyDeepLinkApplyTests {
    private func point(id: Int, name: String = "Science Library") -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: name,
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 12,
            level: .notBusy,
            isOpen: true,
            hoursSummary: nil,
            updatedAt: Date(),
            subLocations: nil
        )
    }

    @Test("Waits while facilities are loading")
    func waitForFacilities() {
        #expect(
            StudyDeepLinkApply.resolve(
                facilityID: 2,
                facilities: nil,
                feedReady: false
            ) == .waitForFacilities
        )
    }

    @Test("Applies known facility")
    func applyKnown() {
        #expect(
            StudyDeepLinkApply.resolve(
                facilityID: 2,
                facilities: [point(id: 2)],
                feedReady: true
            ) == .apply(facilityID: 2)
        )
    }

    @Test("Discards unknown facility so Quietest isn't suppressed")
    func discardUnknown() {
        #expect(
            StudyDeepLinkApply.resolve(
                facilityID: 99,
                facilities: [point(id: 2)],
                feedReady: true
            ) == .discard
        )
    }

    @Test("Failed feed discards instead of waiting forever")
    func failedFeedDiscards() {
        #expect(
            StudyDeepLinkApply.resolve(
                facilityID: 2,
                facilities: nil,
                feedReady: true
            ) == .discard
        )
    }

    @Test("Bare Study applies nil to clear a prior pin")
    func bareClearsPin() {
        #expect(
            StudyDeepLinkApply.resolve(
                facilityID: nil,
                facilities: nil,
                feedReady: false
            ) == .apply(facilityID: nil)
        )
    }
}
