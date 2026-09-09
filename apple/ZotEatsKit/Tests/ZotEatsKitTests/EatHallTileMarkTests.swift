import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallTileMark")
struct EatHallTileMarkTests {
    @Test func namesAreLargeAndBoldSized() {
        #expect(EatHallTileMark.namePointSize == 23)
    }

    @Test func tilesArePreIconRoundedBoxes() {
        #expect(EatHallTileMark.tileMinHeight == 152)
        #expect(EatHallTileMark.tileMinHeight > 140)
    }
}
