import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetTimelineKinds")
struct WidgetTimelineKindsTests {
    @Test func coversEveryShippedGlance() {
        #expect(WidgetTimelineKinds.all == [
            "ZotEatsDiningStatus",
            "ZotEatsTodaysMenu",
            "ZotEatsFavoritesToday",
            "ZotEatsCampusOpen",
            "ZotEatsCampusNext",
            "ZotEatsQuietestLibrary",
        ])
        #expect(Set(WidgetTimelineKinds.all).count == WidgetTimelineKinds.all.count)
        #expect(!WidgetTimelineKinds.all.contains(WidgetTimelineKinds.arcStatus))
    }

    @Test("Eat reload group includes Favorites Today")
    func eatGroupTargetsDiningGlancesOnly() {
        #expect(WidgetTimelineKinds.eat == [
            WidgetTimelineKinds.diningStatus,
            WidgetTimelineKinds.todaysMenu,
            WidgetTimelineKinds.favoritesToday,
        ])
        #expect(Set(WidgetTimelineKinds.eat).isSubset(of: Set(WidgetTimelineKinds.all)))
        #expect(!WidgetTimelineKinds.eat.contains(WidgetTimelineKinds.campusOpen))
        #expect(!WidgetTimelineKinds.eat.contains(WidgetTimelineKinds.quietestLibrary))
    }

    @Test func campusGroupCoversOpenAndNext() {
        #expect(WidgetTimelineKinds.campus == [
            WidgetTimelineKinds.campusOpen,
            WidgetTimelineKinds.campusNext,
        ])
        #expect(Set(WidgetTimelineKinds.campus).isSubset(of: Set(WidgetTimelineKinds.all)))
    }
}
