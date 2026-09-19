import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDishListLayout")
struct EatDishListLayoutTests {
    @Test func dishesHaveAirBetweenCards() {
        #expect(EatDishListLayout.cardSpacing >= 10)
    }

    @Test func rowIDsStayUniqueAcrossFavoriteAndStationCopies() {
        let dish = MenuItem(
            id: "tofu-1",
            name: "Tofu",
            description: nil,
            calories: 200,
            servingSize: nil,
            allergens: [],
            dietaryTags: ["Vegan"]
        )
        let favorite = EatDishListLayout.rows(section: "favorites", items: [dish])
        let station = EatDishListLayout.rows(section: "The Twisted Root", items: [dish])
        #expect(favorite[0].id == "favorites|tofu-1")
        #expect(station[0].id == "The Twisted Root|tofu-1")
        #expect(favorite[0].id != station[0].id)
        #expect(Set([favorite[0].id, station[0].id]).count == 2)
    }
}
