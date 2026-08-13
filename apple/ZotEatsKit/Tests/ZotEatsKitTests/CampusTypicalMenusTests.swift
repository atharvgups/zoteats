import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusTypicalMenus")
struct CampusTypicalMenusTests {
    @Test func matchesCommonChains() {
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "starbucks-at-student-center",
                placeName: "Starbucks"
            ) == .starbucks
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "panda-express-at-west-food-court",
                placeName: "Panda Express"
            ) == .pandaExpress
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "zot-n-go-market",
                placeName: "Zot N Go Market"
            ) == .zotNGo
        )
        #expect(
            CampusTypicalMenus.kind(forPlaceID: "halal-shack", placeName: "Halal Shack") == nil
        )
    }

    @Test func stationsCarryHonestBanner() {
        let stations = CampusTypicalMenus.stations(
            forPlaceID: "subway-at-west-food-court",
            placeName: "Subway"
        )
        #expect(stations != nil)
        #expect(CampusTypicalMenus.isTypical(stations ?? []))
        #expect(stations?.first?.name == CampusTypicalMenus.bannerStationName)
        #expect(stations?.first?.items.first?.name.contains("Not today’s live") == true)
        #expect((stations?.count ?? 0) > 1)
    }

    @Test func zotNGoMentionsDiningHubSource() {
        let stations = CampusTypicalMenus.stations(
            forPlaceID: "zot-n-go-express-mesa-court",
            placeName: "Zot N Go Express @ Mesa Court"
        )
        #expect(stations != nil)
        let note = stations?.first?.items.first?.name ?? ""
        #expect(note.contains("Dining Hub"))
    }
}
