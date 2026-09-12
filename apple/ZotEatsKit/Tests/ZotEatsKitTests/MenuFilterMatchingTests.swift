import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MenuFilterMatching")
struct MenuFilterMatchingTests {
    private func item(
        tags: [String] = [],
        allergens: [String] = []
    ) -> MenuItem {
        MenuItem(
            id: "x",
            name: "Dish",
            description: nil,
            calories: nil,
            servingSize: nil,
            allergens: allergens,
            dietaryTags: tags
        )
    }

    @Test func multiDietRequiresAllTags() {
        let bowl = item(tags: ["Vegan", "Gluten-Free"])
        #expect(MenuFilterMatching.matches(
            item: bowl, dietFilters: ["Vegan", "Gluten-Free"], allergenAvoids: []
        ))
        #expect(!MenuFilterMatching.matches(
            item: bowl, dietFilters: ["Vegan", "Halal"], allergenAvoids: []
        ))
    }

    @Test func allergenAvoidHidesListedAllergensCaseInsensitively() {
        let pasta = item(tags: ["Vegetarian"], allergens: ["Milk", "Wheat"])
        #expect(!MenuFilterMatching.matches(
            item: pasta, dietFilters: [], allergenAvoids: ["milk"]
        ))
        #expect(MenuFilterMatching.matches(
            item: pasta, dietFilters: [], allergenAvoids: ["Peanuts"]
        ))
    }

    @Test func emptyAllergensStayVisibleWhenAvoiding() {
        let mystery = item(tags: ["Vegan"], allergens: [])
        #expect(MenuFilterMatching.matches(
            item: mystery, dietFilters: ["Vegan"], allergenAvoids: ["Eggs"]
        ))
    }

    @Test func filterStationsDropsEmptyStations() {
        let stations = [
            MenuStation(name: "Grill", items: [
                item(tags: ["Halal"], allergens: ["Milk"]),
                item(tags: ["Vegan"], allergens: []),
            ]),
            MenuStation(name: "Dairy", items: [
                item(tags: ["Vegetarian"], allergens: ["Milk"]),
            ]),
        ]
        let filtered = MenuFilterMatching.filterStations(
            stations, dietFilters: [], allergenAvoids: ["Milk"]
        )
        #expect(filtered.map(\.name) == ["Grill"])
        #expect(filtered.first?.items.count == 1)
        #expect(filtered.first?.items.first?.dietaryTags.contains("Vegan") == true)
    }
}
