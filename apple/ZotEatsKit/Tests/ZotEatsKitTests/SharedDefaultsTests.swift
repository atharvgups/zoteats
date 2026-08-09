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
