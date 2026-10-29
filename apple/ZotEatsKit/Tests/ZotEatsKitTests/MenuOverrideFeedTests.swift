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
        #expect(decoded.overrides.count == 1)
        #expect(decoded.overrides.first?.items.first?.name == "Cajun Tofu and White Rice")
        #expect(MenuOverrideFeed.hallMatches("the-anteatery", menuHall: "anteatery"))
        #expect(MenuOverrideFeed.periodMatches("Dinner", menuPeriod: "Dinner"))
    }

    @Test func fetchFallsBackToBundledWhenGitHubIsDown() async {
        let next = await MenuOverrideFeed.fetch(http: FailingHTTP())
        #expect(next == MenuOverrideFeed.bundled)
    }

    @Test func correctionStripsVeganTagsAndAddsShellfishOnThaiRedCurry() {
        let curry = MenuItem(
            id: "curry",
            name: "Thai Red Curry Bowl",
            description: "Thai red curry with sweet potatoes and green beans served with jasmine rice topped with cilantro",
            calories: 553,
            servingSize: nil,
            allergens: [],
            dietaryTags: ["Vegan", "Vegetarian", "Plant Forward", "Gluten-Free"],
            stationID: "1926"
        )
        let home = MenuItem(
            id: "pork", name: "Cajun Roasted Pork Loin", description: nil, calories: 320,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1932"
        )
        let menu = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-29",
            period: "Lunch",
            stations: [
                MenuStation(name: "Fire and Ice", items: [curry], stationID: "1926"),
                MenuStation(name: "Home", items: [home], stationID: "1932"),
            ]
        )
        let combined = MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: menu)
        let fire = combined.stations.first { $0.stationID == "1926" }
        #expect(fire?.items.first?.name == "Thai Red Curry Bowl")
        #expect(fire?.items.first?.dietaryTags == ["Gluten-Free"])
        #expect(fire?.items.first?.allergens == ["Shellfish"])
        #expect(fire?.items.first?.description?.localizedCaseInsensitiveContains("shrimp") == true)
        #expect(combined.stations.contains { $0.name == "Home" })
    }

    @Test func fableTakeoverLandsInTheMiddleLaneWithVerifiedTacos() {
        let twisted = MenuItem(
            id: "tofu", name: "Indian-Spiced Tofu Saute", description: nil, calories: 200,
            servingSize: nil, allergens: [], dietaryTags: ["Vegan"], stationID: "1929"
        )
        let home = MenuItem(
            id: "pork", name: "Cajun Roasted Pork Loin", description: nil, calories: 320,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1932"
        )
        let cake = MenuItem(
            id: "cake", name: "Cookie Crumb Cupcake", description: nil, calories: 280,
            servingSize: nil, allergens: [], dietaryTags: ["Vegetarian"], stationID: "1938"
        )
        let pizza = MenuItem(
            id: "pizza", name: "Pepperoni Pizza", description: nil, calories: 400,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1941"
        )
        let burger = MenuItem(
            id: "burger", name: "Cheeseburger", description: nil, calories: 400,
            servingSize: nil, allergens: [], dietaryTags: [], stationID: "1935"
        )
        let menu = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-29",
            period: "Lunch",
            stations: [
                MenuStation(name: "The Twisted Root", items: [twisted], stationID: "1929"),
                MenuStation(name: "Home", items: [home], stationID: "1932"),
                MenuStation(name: "Bakery", items: [cake], stationID: "1938"),
                MenuStation(name: "Oven", items: [pizza], stationID: "1941"),
                MenuStation(name: "Sizzle Grill", items: [burger], stationID: "1935"),
            ]
        )
        let combined = MenuOverrideFeed.applying(MenuOverrideFeed.bundled, to: menu)
        let names = combined.stations.map(\.name)
        #expect(names.first == "The Twisted Root")
        #expect(names.last == "Sizzle Grill")
        let fableIdx = names.firstIndex(of: "Fable Station Takeover")
        let bakeryIdx = names.firstIndex(of: "Bakery")
        let ovenIdx = names.firstIndex(of: "Oven")
        #expect(fableIdx != nil)
        #expect(bakeryIdx != nil && fableIdx! < bakeryIdx!)
        #expect(ovenIdx != nil && fableIdx! < ovenIdx!)
        let tacos = combined.stations.first { $0.name == "Fable Station Takeover" }?.items.first
        #expect(tacos?.name == "Chipotle Mushroom Soft Tacos")
        #expect(tacos?.calories == 180)
        #expect(tacos?.description == "Sauteed chipotle mushrooms, fire-roasted salsa and warm flour tortilla")
        #expect(tacos?.dietaryTags == ["Vegan", "Vegetarian", "Plant Forward"])
        #expect(DiningService.stationLane(name: "Fable Station Takeover") == .hotEntree)
        #expect(DiningService.isSpecialEventStation(stationName: "Fable Station Takeover"))
        #expect(combined.stations.map(\.stationID) != ["1929", "1932", "1938", "1941", "1935"])
    }

    @Test func decodeReadsCorrectionsAndSpecialStations() {
        let json = Data(
            """
            {"overrides":[{"date":"2026-10-29","hall":"anteatery","period":"Lunch","stationID":"override:fable","stationName":"Fable Station Takeover","kind":"special","items":[{"id":"t1","name":"Chipotle Mushroom Soft Tacos","calories":180,"dietaryTags":["Vegan"]}]}],"corrections":[{"date":"2026-10-29","hall":"anteatery","period":"Lunch","matchName":"Thai Red Curry Bowl","stationID":"1926","removeDietaryTags":["Vegan"],"addAllergens":["Shellfish"],"description":"Contains shrimp."}]}
            """.utf8
        )
        let decoded = MenuOverrideFeed.decode(json)
        #expect(decoded.overrides.first?.isSpecial == true)
        #expect(decoded.corrections.first?.matchName == "Thai Red Curry Bowl")
        #expect(decoded.corrections.first?.addAllergens == ["Shellfish"])
    }
}
