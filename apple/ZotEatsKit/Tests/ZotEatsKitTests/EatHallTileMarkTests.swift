import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallTileMark")
struct EatHallTileMarkTests {
    @Test func namesAreLargerAndHeavierThanMealPills() {
        #expect(EatHallTileMark.namePointSize == 26)
        #expect(EatHallTileMark.nameMinimumPointSize == 16)
        #expect(EatHallTileMark.namePointSize > EatMealPillMark.pointSize)
        #expect(EatHallTileMark.nameMinimumPointSize < EatHallTileMark.namePointSize)
    }

    @Test func statusIsSmallUnderTheName() {
        #expect(EatHallTileMark.statusPointSize == 12)
        #expect(EatHallTileMark.statusPointSize < EatHallTileMark.namePointSize)
        #expect(EatHallTileMark.statusPointSize < EatMealPillMark.pointSize)
    }

    @Test func tilesHaveOneFixedHeightThatContentFills() {
        #expect(EatHallTileMark.tileHeight == 88)
        #expect(EatHallTileMark.contentFillsTile)
        #expect(
            EatHallTileMark.nameBlockHeight
                + EatHallTileMark.statusBlockHeight
                + EatHallTileMark.verticalPadding * 2
                == EatHallTileMark.tileHeight
        )
        #expect(EatHallTileMark.nameBlockHeight == 34)
        #expect(EatHallTileMark.statusBlockHeight == 18)
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
