import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallTileMark")
struct EatHallTileMarkTests {
    @Test func namesShareOneSize() {
        #expect(EatHallTileMark.namePointSize == 15)
    }

    @Test func mesaLodgeForAnteatery() {
        #expect(EatHallTileMark.symbolName(forHallID: "anteatery") == "building.2.fill")
    }

    @Test func leafRingForBrandywine() {
        #expect(EatHallTileMark.symbolName(forHallID: "brandywine") == "leaf.circle.fill")
    }

    @Test func oasisWaterForEveryOasisID() {
        #expect(EatHallTileMark.symbolName(forHallID: "oasis") == "drop.fill")
        #expect(EatHallTileMark.symbolName(forHallID: "the-oasis-dining-hall") == "drop.fill")
    }
}
