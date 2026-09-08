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

    @Test func anteateryIsBuilding() {
        #expect(EatHallTileMark.symbolName(forHallID: "anteatery") == "building.2.fill")
    }

    @Test func brandywineIsLeaf() {
        #expect(EatHallTileMark.symbolName(forHallID: "brandywine") == "leaf.circle.fill")
    }

    @Test func oasisIsDropForEveryOasisID() {
        #expect(EatHallTileMark.symbolName(forHallID: "oasis") == "drop.fill")
        #expect(EatHallTileMark.symbolName(forHallID: "the-oasis-dining-hall") == "drop.fill")
    }

    @Test func unknownHallIsFork() {
        #expect(EatHallTileMark.symbolName(forHallID: "future-hall") == "fork.knife")
    }
}
