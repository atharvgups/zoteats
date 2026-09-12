import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TrackMealPlateItems")
struct TrackMealPlateItemsTests {
    @Test func favoritesOnThisBoardOnly() {
        let burger = MenuItem(
            id: "1", name: "Burger", description: nil, calories: 400,
            servingSize: nil, allergens: [], dietaryTags: []
        )
        let tofu = MenuItem(
            id: "2", name: "Tofu", description: nil, calories: 200,
            servingSize: nil, allergens: [], dietaryTags: []
        )
        let stations = [
            MenuStation(name: "Grill", items: [burger, tofu])
        ]
        let picked = TrackMealPlateItems.favorites(
            from: stations,
            favoriteNames: ["Tofu", "Missing"]
        )
        #expect(picked.map(\.name) == ["Tofu"])
    }

    @Test func emptyFavoritesAddNothing() {
        let item = MenuItem(
            id: "1", name: "Burger", description: nil, calories: 400,
            servingSize: nil, allergens: [], dietaryTags: []
        )
        #expect(
            TrackMealPlateItems.favorites(
                from: [MenuStation(name: "Grill", items: [item])],
                favoriteNames: []
            ).isEmpty
        )
    }
}
