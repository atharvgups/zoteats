import Foundation
import Testing
@testable import ZotEatsKit

@Suite("PlateEmptyCopy")
struct PlateEmptyCopyTests {
    @Test func pointsAtPlusAndSheetCTA() {
        #expect(PlateEmptyCopy.title == "Nothing on your plate yet")
        #expect(PlateEmptyCopy.message.contains("+"))
        #expect(PlateEmptyCopy.message.contains("Add to My Plate"))
    }
}
