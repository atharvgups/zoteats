import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetGlanceExtras")
struct WidgetGlanceExtrasTests {
    private func hall(
        id: String,
        name: String,
        comingSoon: String? = nil,
        periods: [MealPeriodWindow] = []
    ) -> DiningLocation {
        DiningLocation(
            id: id,
            name: name,
            area: "Mesa Court",
            openNow: comingSoon == nil && !periods.isEmpty,
            todayHours: nil,
            availablePeriods: periods.map(\.name),
            periods: periods,
            hoursApproximate: false,
            comingSoonSubtitle: comingSoon
        )
    }

    private func place(id: String, name: String, openNow: Bool) -> CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            category: "Coffee & Cafés",
            openNow: openNow,
            todayHours: openNow ? "7:30 AM – 4:00 PM" : nil,
            closesAtMinutes: openNow ? 16 * 60 : nil
        )
    }

    @Test func hidesComingSoonWhenAsked() {
        let halls = [
            hall(id: "anteatery", name: "The Anteatery"),
            hall(id: "oasis", name: "The Oasis", comingSoon: "Coming Soon"),
        ]
        let shown = WidgetGlanceExtras.comingSoonHalls(from: halls, showComingSoon: true)
        let hidden = WidgetGlanceExtras.comingSoonHalls(from: halls, showComingSoon: false)
        #expect(shown.map(\.id) == ["anteatery", "oasis"])
        #expect(hidden.map(\.id) == ["anteatery"])
    }

    @Test func boardStripTakesNamedDishesFromTheOpenHallMenu() {
        let lunch = MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60 + 30)
        let locations = [
            hall(id: "anteatery", name: "The Anteatery", periods: [lunch]),
        ]
        let menu = DiningMenu(
            locationId: "anteatery",
            date: "2026-08-20",
            period: "Lunch",
            stations: [
                MenuStation(
                    name: "Grill",
                    items: [
                        MenuItem(
                            id: "okra",
                            name: "Crispy Okra",
                            description: nil,
                            calories: nil,
                            servingSize: nil,
                            allergens: [],
                            dietaryTags: ["Vegan", "Vegetarian"]
                        ),
                    ]
                ),
            ]
        )
        let strip = WidgetGlanceExtras.boardStrip(
            locations: locations,
            menu: menu,
            nowMinutes: 12 * 60,
            dietFilters: [],
            allergenAvoids: [],
            favorites: [],
            limit: 3
        )
        #expect(strip?.hallID == "anteatery")
        #expect(strip?.dishes == ["Crispy Okra"])
    }

    @Test func campusFavoritesOnlyDropsNonHearts() {
        let places = [
            place(id: "sb", name: "Starbucks", openNow: true),
            place(id: "panda", name: "Panda Express", openNow: true),
        ]
        let all = WidgetGlanceExtras.campusRows(
            places: places,
            favoriteIDs: ["sb"],
            favoritesOnly: false,
            limit: 4
        )
        let hearts = WidgetGlanceExtras.campusRows(
            places: places,
            favoriteIDs: ["sb"],
            favoritesOnly: true,
            limit: 4
        )
        #expect(all.totalOpen == 2)
        #expect(hearts.totalOpen == 1)
        #expect(hearts.rows.map(\.id) == ["sb"])
    }
}
