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

    @Test("Eat reload group is Dining Status + Today's Menu only")
    func eatGroupTargetsDiningGlancesOnly() {
        #expect(WidgetTimelineKinds.eat == [
            WidgetTimelineKinds.diningStatus,
            WidgetTimelineKinds.todaysMenu,
        ])
        #expect(Set(WidgetTimelineKinds.eat).isSubset(of: Set(WidgetTimelineKinds.all)))
        #expect(!WidgetTimelineKinds.eat.contains(WidgetTimelineKinds.campusOpen))
        #expect(!WidgetTimelineKinds.eat.contains(WidgetTimelineKinds.arcStatus))
        #expect(!WidgetTimelineKinds.eat.contains(WidgetTimelineKinds.quietestLibrary))
    }
}
