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
        #expect(
            CampusTypicalMenus.kind(
                forPlaceID: "the-green-room",
                placeName: "The Green Room"
            ) == .greenRoom
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

    @Test func coreChainPacksCarryLeftoverStationsAndDietTags() {
        let starbucks = foodItems(
            forPlaceID: "starbucks-at-student-center",
            placeName: "Starbucks @ Student Center"
        )
        #expect(starbucks.contains { $0.name.localizedCaseInsensitiveContains("Frappuccino") })
        #expect(starbucks.contains { $0.dietaryTags.contains("Vegan") })

        let panda = foodItems(
            forPlaceID: "panda-express-at-west-food-court",
            placeName: "Panda Express"
        )
        #expect(panda.contains { $0.name.localizedCaseInsensitiveContains("Mushroom Chicken") })
        #expect(panda.contains { $0.name.localizedCaseInsensitiveContains("Brown Steamed Rice") })

        let subway = foodItems(
            forPlaceID: "subway-at-west-food-court",
            placeName: "Subway"
        )
        #expect(subway.contains { $0.name.localizedCaseInsensitiveContains("Salad") })
        #expect(subway.contains { $0.name.localizedCaseInsensitiveContains("Wrap") })

        let jamba = foodItems(
            forPlaceID: "jamba-at-east-food-court",
            placeName: "Jamba"
        )
        #expect(jamba.contains { $0.name.localizedCaseInsensitiveContains("Acai") })
        #expect(jamba.contains { $0.dietaryTags.contains("Vegan") })

        let zot = foodItems(
            forPlaceID: "zot-n-go-market",
            placeName: "Zot N Go Market"
        )
        #expect(zot.contains { $0.name.localizedCaseInsensitiveContains("parfait") })
        #expect(zot.contains { $0.name.localizedCaseInsensitiveContains("Veggie wrap") })
    }

    @Test func javaCityListsNamedDrinksNotCategoryBuckets() {
        let items = foodItems(
            forPlaceID: "java-city-kiosk",
            placeName: "Java City Kiosk"
        )
        #expect(items.contains { $0.name.localizedCaseInsensitiveContains("latte") })
        #expect(items.contains { $0.name.localizedCaseInsensitiveContains("cold brew") })
        #expect(!items.contains { $0.name == "Brewed coffee" })
        #expect(!items.contains { $0.name == "Espresso drinks" })
    }

    @Test func thinChainPacksNowListNamedPlates() {
        let panera = foodItems(forPlaceID: "panera-at-bsc", placeName: "Panera")
        #expect(panera.contains { $0.name.localizedCaseInsensitiveContains("Broccoli Cheddar") })
        let pub = foodItems(forPlaceID: "anthill-pub", placeName: "Anthill Pub")
        #expect(pub.contains { $0.name.localizedCaseInsensitiveContains("Anthill burger") })
        let wushi = foodItems(forPlaceID: "wushiland-boba", placeName: "Wushiland")
        #expect(wushi.contains { $0.name.localizedCaseInsensitiveContains("Brown sugar") })
    }

    private func foodItems(forPlaceID placeID: String, placeName: String) -> [MenuItem] {
        let stations = CampusTypicalMenus.stations(forPlaceID: placeID, placeName: placeName) ?? []
        return stations
            .filter { $0.name != CampusTypicalMenus.bannerStationName }
            .flatMap(\.items)
    }
}
