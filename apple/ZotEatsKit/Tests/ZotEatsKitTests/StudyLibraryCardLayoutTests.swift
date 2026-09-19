import Testing
@testable import ZotEatsKit

@Suite("StudyLibraryCardLayout")
struct StudyLibraryCardLayoutTests {
    @Test("Padding is comfortable, not a 16pt slab and not a dense 8pt row")
    func comfortablePadding() {
        #expect(StudyLibraryCardLayout.contentPadding >= 12)
        #expect(StudyLibraryCardLayout.contentPadding <= 14)
        #expect(StudyLibraryCardLayout.contentPadding < 16)
        #expect(StudyLibraryCardLayout.stackSpacing >= 6)
        #expect(StudyLibraryCardLayout.stackSpacing <= 8)
        #expect(StudyLibraryCardLayout.cardSpacing >= 10)
        #expect(StudyLibraryCardLayout.cardSpacing <= 14)
        #expect(StudyLibraryCardLayout.minTapHeight >= 44)
        #expect(StudyLibraryCardLayout.crowdingPercentSize >= 22)
        #expect(StudyLibraryCardLayout.crowdingPercentSize < 28)
        #expect(StudyLibraryCardLayout.occupancyBarHeight >= 6)
        #expect(StudyLibraryCardLayout.occupancyBarHeight <= 8)
        #expect(StudyLibraryCardLayout.chevronSide >= 20)
        #expect(StudyLibraryCardLayout.chevronSide < 28)
    }

    @Test("Closed cards drop the giant percent row; open cards keep crowding")
    func crowdingChrome() {
        #expect(!StudyLibraryCardLayout.showsCrowdingChrome(isOpen: false))
        #expect(StudyLibraryCardLayout.showsCrowdingChrome(isOpen: true))
    }
}
