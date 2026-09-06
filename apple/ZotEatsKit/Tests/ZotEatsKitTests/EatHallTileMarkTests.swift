import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallTileMark")
struct EatHallTileMarkTests {
    @Test func namesShareOneSize() {
        #expect(EatHallTileMark.namePointSize == 15)
    }

    @Test func tilesAreRoundedRectsNotCircles() {
        #expect(EatHallTileMark.tileMinHeight == 112)
    }

    @Test func mesaForAnteatery() {
        #expect(EatHallTileMark.kind(forHallID: "anteatery") == .mesa)
    }

    @Test func hobbitForBrandywine() {
        #expect(EatHallTileMark.kind(forHallID: "brandywine") == .hobbit)
    }

    @Test func oasisWaterForEveryOasisID() {
        #expect(EatHallTileMark.kind(forHallID: "oasis") == .oasis)
        #expect(EatHallTileMark.kind(forHallID: "the-oasis-dining-hall") == .oasis)
    }
}
