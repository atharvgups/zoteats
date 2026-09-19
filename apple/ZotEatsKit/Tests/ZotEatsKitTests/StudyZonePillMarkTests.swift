import Testing
@testable import ZotEatsKit

@Suite("StudyZonePillMark")
struct StudyZonePillMarkTests {
    @Test func percentSitsInsideWithTrailingRoom() {
        #expect(StudyZonePillMark.horizontalPadding >= 12)
        #expect(StudyZonePillMark.trailingPadding >= 12)
        #expect(StudyZonePillMark.percentMinWidth >= 40)
        #expect(StudyZonePillMark.verticalPadding >= 8)
    }
}
