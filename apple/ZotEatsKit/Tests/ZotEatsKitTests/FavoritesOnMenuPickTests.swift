import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FavoritesOnMenuPick")
struct FavoritesOnMenuPickTests {
    private func station(_ name: String, items: [String]) -> MenuStation {
        MenuStation(
            name: name,
            items: items.map {
                MenuItem(
                    id: $0,
                    name: $0,
                    description: nil,
                    calories: nil,
                    servingSize: nil,
                    allergens: [],
                    dietaryTags: []
                )
            }
        )
    }

    @Test func keepsFavoriteOrderAndSkipsMissing() {
        let rows = FavoritesOnMenuPick.rows(
            favorites: ["Teriyaki", "Soup", "Pasta"],
            stations: [
                station("Grill", items: ["Pasta", "Teriyaki"]),
            ],
            hallID: "anteatery",
            hallName: "The Anteatery",
            period: "Lunch"
        )
        #expect(rows.map(\.dishName) == ["Teriyaki", "Pasta"])
        #expect(rows.first?.period == "Lunch")
    }

    @Test func emptyFavoritesYieldsNoRows() {
        #expect(
            FavoritesOnMenuPick.rows(
                favorites: [],
                stations: [station("Grill", items: ["Soup"])]
            ).isEmpty
        )
    }

    @Test func emptyCopyDependsOnHearts() {
        #expect(FavoritesOnMenuPick.emptyTitle(hasFavorites: false) == "No favorites yet")
        #expect(
            FavoritesOnMenuPick.emptyMessage(hasFavorites: true)
                .contains("Hearted dishes")
        )
    }

    @Test func bestBoardPrefersMoreMatches() {
        let pick = FavoritesOnMenuPick.best(
            favorites: ["Soup", "Pasta", "Rice"],
            boards: [
                .init(
                    hallID: "a",
                    hallName: "Anteatery",
                    period: "Lunch",
                    stations: [station("Grill", items: ["Pasta"])]
                ),
                .init(
                    hallID: "b",
                    hallName: "Brandywine",
                    period: "Lunch",
                    stations: [station("Soup", items: ["Soup", "Rice"])]
                ),
            ]
        )
        #expect(pick?.hallID == "b")
        #expect(pick?.rows.map(\.dishName) == ["Soup", "Rice"])
    }

    @Test func bestPicksSiblingWhenAutoHallHasNoHearts() {
        // Atharv dogfood: heart only on Brandywine while Auto is Anteatery.
        let pick = FavoritesOnMenuPick.best(
            favorites: ["Twisted Root Bowl"],
            boards: [
                .init(
                    hallID: "anteatery",
                    hallName: "The Anteatery",
                    period: "Lunch",
                    stations: [station("Home", items: ["Scrambled Eggs"])]
                ),
                .init(
                    hallID: "brandywine",
                    hallName: "Brandywine",
                    period: "Lunch",
                    stations: [station("Twisted Root", items: ["Twisted Root Bowl"])]
                ),
            ]
        )
        #expect(pick?.hallID == "brandywine")
        #expect(pick?.rows.map(\.dishName) == ["Twisted Root Bowl"])
    }
}
