import Foundation
import Testing
@testable import ZotEatsKit

@Suite("PlateEmptyCopy")
struct PlateEmptyCopyTests {
    @Test func pointsAtPlusAndSheetCTA() {
        #expect(PlateEmptyCopy.title == "Nothing on your plate yet")
        #expect(PlateEmptyCopy.message.contains("+"))
        #expect(PlateEmptyCopy.message.contains("Add to My Plate"))
        #expect(PlateEmptyCopy.footnote.localizedCaseInsensitiveContains("morning"))
    }

    @Test func removeIsALabeledControl() {
        #expect(PlateRemoveCopy.button == "Remove")
        #expect(
            PlateRemoveCopy.accessibilityLabel(dishName: "Farro Salad")
                == "Remove Farro Salad from plate"
        )
        #expect(PlateRemoveCopy.accessibilityLabel(dishName: "  ") == "Remove dish from plate")
    }
}
