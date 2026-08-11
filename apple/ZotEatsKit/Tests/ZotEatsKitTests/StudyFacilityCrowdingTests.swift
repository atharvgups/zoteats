import Testing
@testable import ZotEatsKit

@Suite("StudyFacilityCrowding")
struct StudyFacilityCrowdingTests {
    @Test("Open facilities keep live crowding chrome")
    func openShowsCrowding() {
        #expect(StudyFacilityCrowding.showsLiveCrowding(isOpen: true))
    }

    @Test("Closed facilities hide live crowding chrome")
    func closedHidesCrowding() {
        #expect(!StudyFacilityCrowding.showsLiveCrowding(isOpen: false))
        #expect(StudyFacilityCrowding.closedLevelLabel == "Closed")
        #expect(!StudyFacilityCrowding.closedDetail.isEmpty)
    }
}
