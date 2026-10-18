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

    @Test func lunchFavoritesSkipBreakfastOnlyAllDay() {
        // Atharv Sat Oct 17: switching to Lunch must not keep a breakfast heart
        // that only lives on the shared Available all day dump.
        let stations = [
            station("Grill", items: ["Teriyaki Bowl"]),
            station("Available all day", items: ["Scrambled Eggs", "Seasoned Fries"]),
        ]
        let served = FavoritesOnMenuPick.servedItems(
            favorites: ["Scrambled Eggs", "Teriyaki Bowl", "Seasoned Fries"],
            stations: stations
        )
        #expect(served.map(\.name) == ["Teriyaki Bowl"])
        let rows = FavoritesOnMenuPick.rows(
            favorites: ["Scrambled Eggs", "Teriyaki Bowl", "Seasoned Fries"],
            stations: stations,
            period: "Lunch"
        )
        #expect(rows.map(\.dishName) == ["Teriyaki Bowl"])
        #expect(rows.first?.period == "Lunch")
    }

    @Test func keepsFavoriteAlsoOnTimedStation() {
        let served = FavoritesOnMenuPick.servedItems(
            favorites: ["Coffee"],
            stations: [
                station("Home", items: ["Coffee"]),
                station("Available all day", items: ["Coffee", "Fruit"]),
            ]
        )
        #expect(served.map(\.name) == ["Coffee"])
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

    @Test func bestIgnoresAllDayOnlyHeartsOnLunch() {
        let pick = FavoritesOnMenuPick.best(
            favorites: ["Scrambled Eggs"],
            boards: [
                .init(
                    hallID: "anteatery",
                    hallName: "The Anteatery",
                    period: "Lunch",
                    stations: [
                        station("Grill", items: ["Teriyaki Bowl"]),
                        station("Available all day", items: ["Scrambled Eggs"]),
                    ]
                ),
            ]
        )
        #expect(pick == nil)
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
