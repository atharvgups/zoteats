import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyLibraryTap")
struct StudyLibraryTapTests {
    @Test func openLibraryWithFloorsReveals() {
        #expect(StudyLibraryTap.canRevealFloors(hasFloors: true, isOpen: true))
    }

    @Test func closedOrFloorlessDoesNotInvent() {
        #expect(!StudyLibraryTap.canRevealFloors(hasFloors: true, isOpen: false))
        #expect(!StudyLibraryTap.canRevealFloors(hasFloors: false, isOpen: true))
    }
}
