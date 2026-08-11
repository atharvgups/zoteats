import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetTimelineKinds")
struct WidgetTimelineKindsTests {
    @Test func coversEveryShippedGlance() {
        #expect(WidgetTimelineKinds.all == [
            "ZotEatsDiningStatus",
            "ZotEatsTodaysMenu",
            "ZotEatsCampusOpen",
            "ZotEatsArcStatus",
            "ZotEatsQuietestLibrary",
        ])
        #expect(Set(WidgetTimelineKinds.all).count == WidgetTimelineKinds.all.count)
    }
}
