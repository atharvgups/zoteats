import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusLayout")
struct DiningStatusLayoutTests {
    @Test func bothFamiliesShowUpToThreeHalls() {
        #expect(DiningStatusLayout.hallLimit(isCompact: true) == 3)
        #expect(DiningStatusLayout.hallLimit(isCompact: false) == 3)
        #expect(DiningStatusLayout.hallLimit(isCompact: false, isLarge: true) == 6)
    }

    @Test func densityKicksInAtThreeHalls() {
        #expect(DiningStatusLayout.usesDenseRows(hallCount: 2) == false)
        #expect(DiningStatusLayout.usesDenseRows(hallCount: 3) == true)
    }

    @Test func denseSpacingIsTighterThanTwoHallDefaults() {
        #expect(DiningStatusLayout.rowSpacing(isCompact: true, hallCount: 3)
            < DiningStatusLayout.rowSpacing(isCompact: true, hallCount: 2))
        #expect(DiningStatusLayout.rowSpacing(isCompact: false, hallCount: 3)
            < DiningStatusLayout.rowSpacing(isCompact: false, hallCount: 2))
        #expect(DiningStatusLayout.nameFontSize(isCompact: true, hallCount: 3)
            < DiningStatusLayout.nameFontSize(isCompact: true, hallCount: 2))
        #expect(DiningStatusLayout.statusFontSize(isCompact: false, hallCount: 3)
            < DiningStatusLayout.statusFontSize(isCompact: false, hallCount: 2))
    }
}
