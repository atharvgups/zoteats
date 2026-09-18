import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallTileMark")
struct EatHallTileMarkTests {
    @Test func namesShareOneLargeBoldSize() {
        #expect(EatHallTileMark.namePointSize == 18)
        #expect(EatHallTileMark.nameMinimumPointSize == 12)
        #expect(EatHallTileMark.nameMinimumPointSize < EatHallTileMark.namePointSize)
    }

    @Test func statusSharesOneSize() {
        #expect(EatHallTileMark.statusPointSize == 13)
        #expect(EatHallTileMark.statusPointSize < EatHallTileMark.namePointSize)
    }

    @Test func tilesHaveOneFixedHeight() {
        #expect(EatHallTileMark.tileHeight == 144)
        #expect(EatHallTileMark.nameBlockHeight + EatHallTileMark.statusBlockHeight
            < EatHallTileMark.tileHeight)
        #expect(EatHallTileMark.nameBlockHeight == 28)
    }

    @Test func selectedBorderDoesNotChangeSize() {
        #expect(EatHallTileMark.borderWidth == 1)
    }

    @Test func nameFitIsSharedFromBrandywine() {
        #expect(EatHallTileMark.longestCompactName == "Brandywine")
        let wide = EatHallTileMark.fittedNamePointSize(textWidth: 400)
        let tight = EatHallTileMark.fittedNamePointSize(textWidth: 72)
        #expect(wide == EatHallTileMark.namePointSize)
        #expect(tight == EatHallTileMark.fittedNamePointSize(textWidth: 72))
        #expect(tight >= EatHallTileMark.nameMinimumPointSize)
        #expect(tight <= EatHallTileMark.namePointSize)
    }

    @Test func narrowCardsStillShareOneSize() {
        let a = EatHallTileMark.fittedNamePointSize(textWidth: 80)
        let b = EatHallTileMark.fittedNamePointSize(textWidth: 80)
        #expect(a == b)
        #expect(a < EatHallTileMark.namePointSize)
    }
}
