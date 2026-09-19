import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyLibraryTap")
struct StudyLibraryTapTests {
    @Test func openLibraryWithFloorsReveals() {
        #expect(StudyLibraryTap.canRevealFloors(hasFloors: true, isOpen: true))
    }

    @Test func closedOrFloorlessDoesNotInventLivePercents() {
        #expect(!StudyLibraryTap.canRevealFloors(hasFloors: true, isOpen: false))
        #expect(!StudyLibraryTap.canRevealFloors(hasFloors: false, isOpen: true))
    }

    @Test("Header tap is never a no-op — closed libraries still expand")
    func closedLibrariesStillToggle() {
        #expect(StudyLibraryTap.canToggleExpand())
    }

    @Test func floorsHint() {
        #expect(StudyLibraryTap.floorsHint(floorCount: 4, isExpanded: false) == "4 floors")
        #expect(StudyLibraryTap.floorsHint(floorCount: 1, isExpanded: false) == "1 floor")
        #expect(StudyLibraryTap.floorsHint(floorCount: 0, isExpanded: false) == "Floors")
        #expect(StudyLibraryTap.floorsHint(floorCount: 4, isExpanded: true) == "Hide floors")
    }

    @Test func expandedEmptyDetailIsHonest() {
        #expect(
            StudyLibraryTap.expandedEmptyDetail(isOpen: false)
                == "Floor crowding updates when this library is open"
        )
        #expect(
            StudyLibraryTap.expandedEmptyDetail(isOpen: true)
                == "No floor breakdown right now"
        )
    }
}
