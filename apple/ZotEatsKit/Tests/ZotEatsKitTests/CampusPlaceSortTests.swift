import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusPlaceSort")
struct CampusPlaceSortTests {
    private func place(
        id: String,
        name: String,
        category: String = "Food Courts",
        openNow: Bool = false
    ) -> CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            category: category,
            openNow: openNow,
            todayHours: openNow ? "11:00 AM – 8:00 PM" : nil
        )
    }

    @Test func twistedRootDetectedByName() {
        #expect(CampusPlaceSort.isTwistedRootPreferred(place(id: "tr", name: "Twisted Root")))
        #expect(CampusPlaceSort.isTwistedRootPreferred(place(id: "tr2", name: "The Twisted Root @ BSC")))
        #expect(!CampusPlaceSort.isTwistedRootPreferred(place(id: "px", name: "Panda Express")))
    }

    @Test func mainListPutsTwistedRootFirstEvenWhenClosed() {
        let sorted = CampusPlaceSort.sortMain([
            place(id: "px", name: "Panda Express", openNow: true),
            place(id: "tr", name: "Twisted Root", openNow: false),
            place(id: "sb", name: "Starbucks @ Student Center", openNow: true),
        ])
        #expect(sorted.map(\.id) == ["tr", "px", "sb"])
    }

    @Test func emptyFavoritesStillPinsTwistedRootInMain() {
        let partition = CampusPlaceSort.partition(
            places: [
                place(id: "px", name: "Panda Express", openNow: true),
                place(id: "tr", name: "Twisted Root", openNow: false),
            ],
            favoriteIDs: []
        )
        #expect(partition.favorites.isEmpty)
        #expect(partition.main.map(\.id) == ["tr", "px"])
    }

    @Test func favoritesDedupedFromMainList() {
        let places = [
            place(id: "tr", name: "Twisted Root", openNow: true),
            place(id: "px", name: "Panda Express", openNow: true),
            place(id: "sb", name: "Starbucks @ Student Center", openNow: false),
        ]
        let partition = CampusPlaceSort.partition(
            places: places,
            favoriteIDs: ["tr", "sb"]
        )
        #expect(partition.favorites.map(\.id) == ["tr", "sb"])
        #expect(partition.main.map(\.id) == ["px"])
        #expect(!partition.main.contains(where: { $0.id == "tr" }))
    }

    @Test func favoritedTwistedRootDoesNotDoubleInBrandGroups() {
        let places = [
            place(id: "tr", name: "Twisted Root", openNow: true),
            place(id: "px", name: "Panda Express", openNow: false),
        ]
        let partition = CampusPlaceSort.partition(places: places, favoriteIDs: ["tr"])
        let brands = CampusPlaceSort.brandGroups(from: partition.main)
        #expect(partition.favorites.map(\.id) == ["tr"])
        #expect(brands.map(\.brand) == ["Panda Express"])
    }

    @Test func brandGroupsPinTwistedRootBrandFirst() {
        let brands = CampusPlaceSort.brandGroups(from: [
            place(id: "px", name: "Panda Express", openNow: true),
            place(id: "tr", name: "Twisted Root", openNow: false),
            place(id: "sb1", name: "Starbucks @ Student Center", openNow: true),
            place(id: "sb2", name: "Starbucks @ Langson", openNow: false),
        ])
        #expect(brands.first?.brand == "Twisted Root")
    }

    @Test func favoritesPreferOpenThenName() {
        let sorted = CampusPlaceSort.sortFavorites([
            place(id: "b", name: "B Spot", openNow: false),
            place(id: "a", name: "A Spot", openNow: false),
            place(id: "c", name: "C Spot", openNow: true),
        ])
        #expect(sorted.map(\.id) == ["c", "a", "b"])
    }
}

@Suite("CampusTypeFilter")
struct CampusTypeFilterTests {
    @Test func foodCoversCourtsAndPubs() {
        #expect(CampusTypeFilter.food.matches(category: "Food Courts"))
        #expect(CampusTypeFilter.food.matches(category: "Restaurants & Pubs"))
        #expect(!CampusTypeFilter.food.matches(category: "Coffee & Cafés"))
    }

    @Test func allMatchesEverything() {
        for category in ["Coffee & Cafés", "Food Courts", "Markets", "Restaurants & Pubs"] {
            #expect(CampusTypeFilter.all.matches(category: category))
        }
    }

    @Test func coffeeAndMarketsAreNarrow() {
        #expect(CampusTypeFilter.coffee.matches(category: "Coffee & Cafés"))
        #expect(!CampusTypeFilter.coffee.matches(category: "Markets"))
        #expect(CampusTypeFilter.markets.matches(category: "Markets"))
        #expect(!CampusTypeFilter.markets.matches(category: "Food Courts"))
    }
}

@Suite("CampusMenuNormalize")
struct CampusMenuNormalizeTests {
    private func item(_ name: String) -> MenuItem {
        MenuItem(
            id: name,
            name: name,
            description: nil,
            calories: nil,
            servingSize: nil,
            allergens: [],
            dietaryTags: []
        )
    }

    @Test func renamesAllDayAndPinsLast() {
        let stations = CampusMenuNormalize.stations([
            MenuStation(name: "All Day", items: [item("Fruit")]),
            MenuStation(name: "Lunch", items: [item("Bowl")]),
        ])
        #expect(stations.map(\.name) == ["Lunch", CampusMenuNormalize.availableAllDay])
    }

    @Test func dedupesAllDayItemsAcrossDupSections() {
        let stations = CampusMenuNormalize.stations([
            MenuStation(name: "All Day", items: [item("Fruit"), item("Yogurt")]),
            MenuStation(name: "Available all day", items: [item("fruit"), item("Chips")]),
            MenuStation(name: "Dinner", items: [item("Pasta")]),
        ])
        let allDay = stations.last
        #expect(allDay?.name == CampusMenuNormalize.availableAllDay)
        #expect(allDay?.items.map(\.name) == ["Fruit", "Yogurt", "Chips"])
        #expect(stations.first?.name == "Dinner")
    }

    @Test func leavesMenusWithoutAllDayAlone() {
        let stations = CampusMenuNormalize.stations([
            MenuStation(name: "Lunch", items: [item("Bowl")]),
        ])
        #expect(stations.map(\.name) == ["Lunch"])
    }
}
