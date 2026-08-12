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
        #expect(matches.contains(.init(
            dishName: "Chicken Tikka", hallName: "Brandywine", locationId: "brandywine", period: "Dinner"
        )))
        #expect(matches.contains(.init(
            dishName: "Crispy Okra", hallName: "The Anteatery", locationId: "anteatery", period: "Lunch"
        )))
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
        #expect(matches[0].locationId == "anteatery")
    }

    @Test func prefersCurrentlyServingOverUpcoming() {
        // Anteatery Dinner (upcoming) is scanned first; Brandywine Lunch is live.
        let matches = FavoritesMatcher.matches(
            favorites: ["Crispy Okra"],
            menus: [
                menu("anteatery", period: "Dinner", dishes: ["Crispy Okra"]),
                menu("brandywine", period: "Lunch", dishes: ["Crispy Okra"]),
            ],
            hallNames: ["anteatery": "The Anteatery", "brandywine": "Brandywine"],
            isServing: { locationId, period in
                locationId == "brandywine" && period == "Lunch"
            }
        )
        #expect(matches.count == 1)
        #expect(matches[0].locationId == "brandywine")
        #expect(matches[0].hallName == "Brandywine")
        #expect(matches[0].period == "Lunch")
    }

    @Test func prefersSoonerUpcomingLunchOverDinnerWhenNeitherServing() {
        // Dinner scanned first — must still pin Lunch (sooner open).
        let matches = FavoritesMatcher.matches(
            favorites: ["Crispy Okra"],
            menus: [
                menu("anteatery", period: "Dinner", dishes: ["Crispy Okra"]),
                menu("brandywine", period: "Lunch", dishes: ["Crispy Okra"]),
            ],
            hallNames: ["anteatery": "The Anteatery", "brandywine": "Brandywine"],
            isServing: { _, _ in false },
            periodStartMinutes: { locationId, period in
                switch (locationId, MealPeriodPill.canonical(period)) {
                case ("brandywine", "Lunch"): return 11 * 60
                case ("anteatery", "Dinner"): return 16 * 60 + 30
                default: return nil
                }
            }
        )
        #expect(matches.count == 1)
        #expect(matches[0].locationId == "brandywine")
        #expect(matches[0].period == "Lunch")
    }

    @Test func prefersEarlierPillWhenStartsUnknown() {
        let matches = FavoritesMatcher.matches(
            favorites: ["Soup"],
            menus: [
                menu("anteatery", period: "Dinner", dishes: ["Soup"]),
                menu("anteatery", period: "Lunch", dishes: ["Soup"]),
            ],
            hallNames: ["anteatery": "The Anteatery"],
            isServing: { _, _ in false }
        )
        #expect(matches.count == 1)
        #expect(matches[0].period == "Lunch")
    }

    @Test func keepsFirstWhenBothServingOrBothUpcoming() {
        let bothUpcoming = FavoritesMatcher.matches(
            favorites: ["Soup"],
            menus: [
                menu("anteatery", period: "Dinner", dishes: ["Soup"]),
                menu("brandywine", period: "Dinner", dishes: ["Soup"]),
            ],
            hallNames: ["anteatery": "The Anteatery", "brandywine": "Brandywine"],
            isServing: { _, _ in false }
        )
        #expect(bothUpcoming.count == 1)
        #expect(bothUpcoming[0].locationId == "anteatery")

        let bothServing = FavoritesMatcher.matches(
            favorites: ["Soup"],
            menus: [
                menu("anteatery", period: "Lunch", dishes: ["Soup"]),
                menu("brandywine", period: "Lunch", dishes: ["Soup"]),
            ],
            hallNames: ["anteatery": "The Anteatery", "brandywine": "Brandywine"],
            isServing: { _, _ in true }
        )
        #expect(bothServing.count == 1)
        #expect(bothServing[0].locationId == "anteatery")
    }

    @Test func noFavoritesMeansNoWork() {
        #expect(FavoritesMatcher.matches(favorites: [], menus: [menu("anteatery", period: "Lunch", dishes: ["A"])], hallNames: [:]).isEmpty)
    }

    @Test func dedupeKeyIsPerDayDishMealAndPhase() {
        let match = FavoritesMatcher.Match(
            dishName: "Crispy Okra", hallName: "X", locationId: "anteatery", period: "Lunch"
        )
        #expect(
            match.dedupeKey(dateISO: "2026-07-16", phase: .upcoming)
                == "2026-07-16|crispy okra|lunch|upcoming"
        )
        #expect(
            match.dedupeKey(dateISO: "2026-07-16", phase: .serving)
                == "2026-07-16|crispy okra|lunch|serving"
        )
        #expect(
            match.dedupeKey(dateISO: "2026-07-16", phase: .upcoming)
                != match.dedupeKey(dateISO: "2026-07-16", phase: .serving)
        )
        #expect(match.legacyDedupeKey(dateISO: "2026-07-16") == "2026-07-16|crispy okra")
    }

    @Test func shouldNotifyAllowsServingUpgradeAfterUpcoming() {
        let match = FavoritesMatcher.Match(
            dishName: "Crispy Okra",
            hallName: "The Anteatery",
            locationId: "anteatery",
            period: "Lunch"
        )
        let upcomingKey = match.dedupeKey(dateISO: "2026-07-16", phase: .upcoming)
        #expect(
            FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: false,
                alreadyNotified: []
            )
        )
        #expect(
            !FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: false,
                alreadyNotified: [upcomingKey]
            )
        )
        #expect(
            FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: true,
                alreadyNotified: [upcomingKey]
            )
        )
        #expect(
            !FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: true,
                alreadyNotified: [
                    upcomingKey,
                    match.dedupeKey(dateISO: "2026-07-16", phase: .serving),
                ]
            )
        )
    }

    @Test func shouldNotifyLegacyUpcomingBlocksOnlyUpcoming() {
        let match = FavoritesMatcher.Match(
            dishName: "Crispy Okra",
            hallName: "The Anteatery",
            locationId: "anteatery",
            period: "Lunch"
        )
        let legacy = match.legacyDedupeKey(dateISO: "2026-07-16")
        #expect(
            !FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: false,
                alreadyNotified: [legacy]
            )
        )
        #expect(
            FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: "2026-07-16",
                servingNow: true,
                alreadyNotified: [legacy]
            )
        )
    }

    @Test func dinnerPhaseKeysDifferFromLunch() {
        let lunch = FavoritesMatcher.Match(
            dishName: "Soup", hallName: "X", locationId: "anteatery", period: "Lunch"
        )
        let dinner = FavoritesMatcher.Match(
            dishName: "Soup", hallName: "X", locationId: "anteatery", period: "Dinner"
        )
        #expect(
            lunch.dedupeKey(dateISO: "2026-07-16", phase: .upcoming)
                != dinner.dedupeKey(dateISO: "2026-07-16", phase: .upcoming)
        )
    }

    @Test func shouldNotifyBlocksDinnerWhileLunchStillRelevant() {
        let lunch = FavoritesMatcher.Match(
            dishName: "Soup",
            hallName: "The Anteatery",
            locationId: "anteatery",
            period: "Lunch"
        )
        let dinner = FavoritesMatcher.Match(
            dishName: "Soup",
            hallName: "The Anteatery",
            locationId: "anteatery",
            period: "Dinner"
        )
        let lunchServing = lunch.dedupeKey(dateISO: "2026-07-16", phase: .serving)
        #expect(
            !FavoritesMatcher.shouldNotify(
                match: dinner,
                dateISO: "2026-07-16",
                servingNow: false,
                alreadyNotified: [lunchServing],
                earlierPeriodStillOpen: { $0 == "Lunch" }
            )
        )
        #expect(
            FavoritesMatcher.shouldNotify(
                match: dinner,
                dateISO: "2026-07-16",
                servingNow: false,
                alreadyNotified: [lunchServing],
                earlierPeriodStillOpen: { _ in false }
            )
        )
    }
}
