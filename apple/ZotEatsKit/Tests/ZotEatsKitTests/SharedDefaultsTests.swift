import Testing
@testable import ZotEatsKit

@Suite("SharedDefaults — favorite prioritization")
struct SharedDefaultsTests {
    @Test func favoritesFloatToTheTop() {
        let result = SharedDefaults.prioritizeFavorites(
            dishes: ["A", "B", "C", "D"],
            favorites: ["c", "A"]
        )
        #expect(result.ordered == ["A", "C", "B", "D"])
        #expect(result.favorited == ["A", "C"])
    }

    @Test func emptyFavoritesKeepsOrder() {
        let result = SharedDefaults.prioritizeFavorites(
            dishes: ["Soup", "Salad"],
            favorites: []
        )
        #expect(result.ordered == ["Soup", "Salad"])
        #expect(result.favorited.isEmpty)
    }

    @Test func unmatchedFavoritesAreIgnored() {
        let result = SharedDefaults.prioritizeFavorites(
            dishes: ["Tacos"],
            favorites: ["Pizza"]
        )
        #expect(result.ordered == ["Tacos"])
        #expect(result.favorited.isEmpty)
    }
}

@Suite("SharedDefaults — Today's Menu filter pipeline")
struct SharedDefaultsTodaysMenuTests {
    private func item(
        name: String,
        tags: [String] = [],
        allergens: [String] = []
    ) -> MenuItem {
        MenuItem(
            id: name,
            name: name,
            description: nil,
            calories: nil,
            servingSize: nil,
            allergens: allergens,
            dietaryTags: tags
        )
    }

    @Test func clearMenuFiltersWipesDietAndAllergens() {
        SharedDefaults.setDietFilters(["Vegan"])
        SharedDefaults.setAllergenAvoids(["Milk"])
        SharedDefaults.clearMenuFilters()
        #expect(SharedDefaults.dietFilters().isEmpty)
        #expect(SharedDefaults.allergenAvoids().isEmpty)
    }

    @Test func dietFilterAndFavoritesTogether() {
        let stations = [
            MenuStation(name: "Grill", items: [
                item(name: "Steak", tags: ["Halal"], allergens: ["Milk"]),
                item(name: "Tofu Bowl", tags: ["Vegan"], allergens: []),
                item(name: "Veggie Wrap", tags: ["Vegan"], allergens: []),
            ]),
        ]
        let result = SharedDefaults.todaysMenuDishes(
            stations: stations,
            dietFilters: ["Vegan"],
            allergenAvoids: [],
            favorites: ["Veggie Wrap"]
        )
        #expect(result.ordered == ["Veggie Wrap", "Tofu Bowl"])
        #expect(result.favorited == ["Veggie Wrap"])
        #expect(!result.filtersEmptiedMenu)
    }

    @Test func allergenAvoidCanEmptyAnOtherwisePostedMenu() {
        let stations = [
            MenuStation(name: "Dairy", items: [
                item(name: "Mac", tags: [], allergens: ["Milk"]),
                item(name: "Cheese Pizza", tags: [], allergens: ["Milk", "Wheat"]),
            ]),
        ]
        let result = SharedDefaults.todaysMenuDishes(
            stations: stations,
            dietFilters: [],
            allergenAvoids: ["Milk"],
            favorites: []
        )
        #expect(result.ordered.isEmpty)
        #expect(result.filtersEmptiedMenu)
    }

    @Test func noPostedItemsIsNotFilterEmpty() {
        let result = SharedDefaults.todaysMenuDishes(
            stations: [MenuStation(name: "Closed", items: [])],
            dietFilters: ["Vegan"],
            allergenAvoids: [],
            favorites: []
        )
        #expect(result.ordered.isEmpty)
        #expect(!result.filtersEmptiedMenu)
    }

    @Test func dedupesNamesCaseInsensitively() {
        let stations = [
            MenuStation(name: "A", items: [item(name: "Soup", tags: ["Vegan"])]),
            MenuStation(name: "B", items: [item(name: "soup", tags: ["Vegan"])]),
        ]
        let result = SharedDefaults.todaysMenuDishes(
            stations: stations,
            dietFilters: ["Vegan"],
            allergenAvoids: [],
            favorites: []
        )
        #expect(result.ordered == ["Soup"])
    }
}

@Suite("SharedDefaults — meal reviews")
struct SharedDefaultsMealReviewTests {
    @Test func roundTripsAReview() {
        SharedDefaults.setMealReviews([])
        let review = MealReview(dishName: "Grill Chicken", stars: 4, note: "Crispy", updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        SharedDefaults.setMealReviews([review])
        let loaded = SharedDefaults.mealReviews()
        #expect(loaded.count == 1)
        #expect(loaded[0].dishName == "Grill Chicken")
        #expect(loaded[0].stars == 4)
        #expect(loaded[0].note == "Crispy")
        SharedDefaults.setMealReviews([])
        #expect(SharedDefaults.mealReviews().isEmpty)
    }
}
