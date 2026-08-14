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
            CampusTypicalMenus.kind(
                forPlaceID: "halal-shack",
                placeName: "Halal Shack"
            ) == .halalShack
        )
    }

    @Test func halalShackCarriesHonestBannerAndHalalTags() {
        let stations = CampusTypicalMenus.stations(
            forPlaceID: "halal-shack",
            placeName: "Halal Shack"
        )
        #expect(stations != nil)
        #expect(CampusTypicalMenus.isTypical(stations ?? []))
        #expect(stations?.first?.name == CampusTypicalMenus.bannerStationName)
        let food = (stations ?? []).filter { $0.name != CampusTypicalMenus.bannerStationName }
        let items = food.flatMap(\.items)
        #expect(items.contains { $0.name.localizedCaseInsensitiveContains("chicken over rice") })
        #expect(items.contains { $0.dietaryTags.contains("Halal") })
        let vegan = MenuFilterMatching.filterStations(
            food,
            dietFilters: ["Vegan"],
            allergenAvoids: []
        )
        #expect(vegan.flatMap(\.items).contains { $0.name.localizedCaseInsensitiveContains("falafel") })
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

    @Test func matchesPhoenixFoodCourtBrands() {
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "choolaah-at-phoenix-food-court",
                placeName: "Choolaah"
            ) == .choolaah
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "wushiland-boba",
                placeName: "Wushiland Boba"
            ) == .wushiland
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "tortilla-fresca-at-phoenix-food-court",
                placeName: "Tortilla Fresca"
            ) == .tortillaFresca
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "anthill-pub",
                placeName: "Anthill Pub & Grille"
            ) == .anthillPub
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "greens-to-go-at-phoenix-food-court",
                placeName: "Greens to Go"
            ) == .greensToGo
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "b-f-at-phoenix-food-court",
                placeName: "B+F"
            ) == .bAndF
        )
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "java-city-kiosk",
                placeName: "Java City"
            ) == .javaCity
        )
    }

    @Test func veganTaggedTypicalItemsSurviveDietFilter() {
        let stations = CampusTypicalMenus.stations(
            forPlaceID: "subway-at-west-food-court",
            placeName: "Subway"
        ) ?? []
        let food = stations.filter { $0.name != CampusTypicalMenus.bannerStationName }
        let filtered = MenuFilterMatching.filterStations(
            food,
            dietFilters: ["Vegan"],
            allergenAvoids: []
        )
        #expect(!filtered.isEmpty)
        #expect(filtered.flatMap(\.items).contains { $0.name.contains("Veggie") })
    }
}
