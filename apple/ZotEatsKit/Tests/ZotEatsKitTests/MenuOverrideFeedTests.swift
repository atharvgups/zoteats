import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MenuOverrideFeed")
struct MenuOverrideFeedTests {
    @Test func bundledInsertsCajunTofuWithoutReorderingOtherStations() {
        let home = MenuItem(
            id: "pork", name: "Cajun Roasted Pork Loin", description: nil, calories: 320,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1932"
        )
        let burger = MenuItem(
            id: "burger", name: "Cheeseburger", description: nil, calories: 400,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1935"
        )
        let menu = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-28",
            period: "Dinner",
            stations: [
                MenuStation(name: "Home", items: [home], stationID: "1932"),
                MenuStation(name: "Sizzle Grill", items: [burger], stationID: "1935"),
            ]
        )
        let combined = MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: menu)
        #expect(combined.stations.first?.stationID == "1929")
        #expect(combined.stations.first?.name.contains("Twisted Root") == true)
        #expect(combined.stations.first?.items.map(\.name) == ["Cajun Tofu and White Rice"])
        #expect(combined.stations.first?.items.first?.dietaryTags.contains("Vegan") == true)
        #expect(combined.stations.map(\.stationID) == ["1929", "1932", "1935"])
    }

    @Test func overrideJoinsExistingTwistedRootAndSkipsOtherDays() {
        let rice = MenuItem(
            id: "rice", name: "Jasmine Rice", description: nil, calories: 160,
            servingSize: nil, allergens: [], dietaryTags: ["Vegan"], stationID: "1929"
        )
        let dinner = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-28",
            period: "Dinner",
            stations: [MenuStation(name: "The Twisted Root", items: [rice], stationID: "1929")]
        )
        let joined = MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: dinner)
        #expect(joined.stations.first?.items.map(\.name) == ["Jasmine Rice", "Cajun Tofu and White Rice"])

        let lunch = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-28",
            period: "Lunch",
            stations: [MenuStation(name: "The Twisted Root", items: [rice], stationID: "1929")]
        )
        #expect(MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: lunch) == lunch)

        let tomorrow = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-29",
            period: "Dinner",
            stations: [MenuStation(name: "The Twisted Root", items: [rice], stationID: "1929")]
        )
        #expect(MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: tomorrow) == tomorrow)
    }

    @Test func decodeMatchesBundledCajunTofu() {
        let json = Data(
            """
            {"overrides":[{"date":"2026-10-28","hall":"anteatery","period":"Dinner","stationID":"1929","stationName":"The Twisted Root","verified":true,"items":[{"id":"override:anteatery-dinner-1929-cajun-tofu-2026-10-28","name":"Cajun Tofu and White Rice","dietaryTags":["Vegan","Vegetarian"]}]}]}
            """.utf8
        )
        let decoded = MenuOverrideFeed.decode(json)
        #expect(decoded.count == 1)
        #expect(decoded.first?.items.first?.name == "Cajun Tofu and White Rice")
        #expect(MenuOverrideFeed.hallMatches("the-anteatery", menuHall: "anteatery"))
        #expect(MenuOverrideFeed.periodMatches("Dinner", menuPeriod: "Dinner"))
    }

    @Test func fetchFallsBackToBundledWhenGitHubIsDown() async {
        let next = await MenuOverrideFeed.fetch(http: FailingHTTP())
        #expect(next == MenuOverrideFeed.bundled)
    }
}
