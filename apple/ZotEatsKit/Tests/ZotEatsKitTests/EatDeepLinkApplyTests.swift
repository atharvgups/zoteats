import Testing
@testable import ZotEatsKit

@Suite("EatDeepLinkApply")
struct EatDeepLinkApplyTests {
    private let halls = [
        DiningLocation(
            id: "anteatery",
            name: "The Anteatery",
            area: "Mesa Court",
            openNow: true,
            todayHours: "7:15 AM – 8:00 PM",
            availablePeriods: ["Breakfast", "Lunch", "Dinner"],
            hoursApproximate: false
        ),
        DiningLocation(
            id: "brandywine",
            name: "Brandywine",
            area: "Middle Earth",
            openNow: false,
            todayHours: "7:15 AM – 8:00 PM",
            availablePeriods: ["Breakfast", "Lunch", "Dinner"],
            hoursApproximate: false
        ),
        DiningLocation(
            id: "oasis",
            name: "The Oasis",
            area: "Mesa Court",
            openNow: false,
            todayHours: nil,
            availablePeriods: [],
            hoursApproximate: true
        ),
    ]

    @Test("Waits while locations are loading")
    func waitForLocations() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "anteatery",
                needsLocations: true,
                locations: nil,
                feedReady: false
            ) == .waitForLocations
        )
    }

    @Test("Applies known hall")
    func applyKnownHall() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "anteatery",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: "anteatery")
        )
    }

    @Test("Discards unknown hall so period/dish don't hit the wrong board")
    func discardUnknownHall() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "ghost-hall",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .discard
        )
    }

    @Test("Failed feed discards instead of waiting forever")
    func failedFeedDiscards() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "anteatery",
                needsLocations: true,
                locations: nil,
                feedReady: true
            ) == .discard
        )
    }

    @Test("Period-only applies without changing hall")
    func periodOnly() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: nil,
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: nil)
        )
    }

    @Test("Bare eat / dish-only skips the locations wait")
    func bareOrDishOnly() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: nil,
                needsLocations: false,
                locations: nil,
                feedReady: false
            ) == .apply(hallID: nil)
        )
    }

    @Test("Hub keys and Oasis aliases open the Eat feed hall")
    func hubKeysResolveToFeedIDs() {
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "the-anteatery",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: "anteatery")
        )
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "brandywine",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: "brandywine")
        )
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "the-oasis-dining-hall",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: "oasis")
        )
        #expect(
            EatDeepLinkApply.resolve(
                hallID: "The Oasis",
                needsLocations: true,
                locations: halls,
                feedReady: true
            ) == .apply(hallID: "oasis")
        )
    }
}
