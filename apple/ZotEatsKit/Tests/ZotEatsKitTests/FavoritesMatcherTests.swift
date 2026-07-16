import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FavoritesMatcher")
struct FavoritesMatcherTests {
    private func menu(_ hall: String, period: String, dishes: [String]) -> DiningMenu {
        DiningMenu(
            locationId: hall,
            date: "2026-07-16",
            period: period,
            stations: [MenuStation(name: "Home", items: dishes.map {
                MenuItem(id: $0, name: $0, description: nil, calories: nil,
                         servingSize: nil, allergens: [], dietaryTags: [])
            })]
        )
    }

    @Test func findsServedFavoritesCaseInsensitively() {
        let matches = FavoritesMatcher.matches(
            favorites: ["crispy okra", "Chicken Tikka"],
            menus: [
                menu("anteatery", period: "Lunch", dishes: ["Crispy Okra", "Texas Toast"]),
                menu("brandywine", period: "Dinner", dishes: ["Chicken Tikka"]),
            ],
            hallNames: ["anteatery": "The Anteatery", "brandywine": "Brandywine"]
        )
        #expect(matches.count == 2)
        #expect(matches.contains(.init(dishName: "Chicken Tikka", hallName: "Brandywine", period: "Dinner")))
        #expect(matches.contains(.init(dishName: "Crispy Okra", hallName: "The Anteatery", period: "Lunch")))
    }

    @Test func oneMatchPerDishAcrossMenus() {
        let matches = FavoritesMatcher.matches(
            favorites: ["Crispy Okra"],
            menus: [
                menu("anteatery", period: "Lunch", dishes: ["Crispy Okra"]),
                menu("anteatery", period: "Dinner", dishes: ["Crispy Okra"]),
            ],
            hallNames: [:]
        )
        #expect(matches.count == 1)
        #expect(matches[0].period == "Lunch")
        #expect(matches[0].hallName == "The Anteatery") // directory fallback
    }

    @Test func noFavoritesMeansNoWork() {
        #expect(FavoritesMatcher.matches(favorites: [], menus: [menu("anteatery", period: "Lunch", dishes: ["A"])], hallNames: [:]).isEmpty)
    }

    @Test func dedupeKeyIsPerDayPerDish() {
        let match = FavoritesMatcher.Match(dishName: "Crispy Okra", hallName: "X", period: "Lunch")
        #expect(match.dedupeKey(dateISO: "2026-07-16") == "2026-07-16|crispy okra")
        #expect(match.dedupeKey(dateISO: "2026-07-17") != match.dedupeKey(dateISO: "2026-07-16"))
    }
}
