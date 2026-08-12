import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealActivityDeepLink")
struct MealActivityDeepLinkTests {
    /// Thursday 2026-07-09 7:30 PM Pacific — Dinner still live, ends 8 PM.
    private let sevenThirty = ISO8601DateFormatter().date(from: "2026-07-10T02:30:00Z")!
    private let eightPM = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
    private let eightOhOne = ISO8601DateFormatter().date(from: "2026-07-10T03:01:00Z")!

    @Test func liveLinksTodaysMealPill() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: "Breakfast",
            now: sevenThirty
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == "Dinner")
        #expect(link.date == nil)
    }

    @Test func afterCloseJumpsToTomorrowBoard() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: "Breakfast",
            now: eightOhOne
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == "Breakfast")
        #expect(link.date == "2026-07-10")
    }

    @Test func afterCloseWithoutTomorrowIsHallOnly() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: nil,
            now: eightOhOne
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == nil)
        #expect(link.date == nil)
    }

    @Test func limitedDinnerCanonicalizesWhileLive() {
        let link = MealActivityDeepLink.link(
            hallID: "brandywine",
            period: "Limited Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: "Brunch",
            now: sevenThirty
        )
        #expect(link.period == "Dinner")
    }

    @Test func brunchTomorrowCanonicalizesAfterClose() {
        let link = MealActivityDeepLink.link(
            hallID: "brandywine",
            period: "Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: "Brunch",
            now: eightOhOne
        )
        #expect(link.period == "Breakfast")
        #expect(link.date == "2026-07-10")
    }
}

@Suite("MealCountdownChrome")
struct MealCountdownChromeTests {
    @Test func lockAndIslandFlipAfterEnd() {
        #expect(
            MealCountdownChrome.lockStatus(period: "Dinner", hasEnded: false) == "Dinner ends in"
        )
        #expect(
            MealCountdownChrome.lockStatus(period: "Dinner", hasEnded: true) == "Dinner has ended"
        )
        #expect(
            MealCountdownChrome.islandBottom(period: "Lunch", hasEnded: false)
                .contains("wrapping up")
        )
        #expect(
            MealCountdownChrome.islandBottom(period: "Lunch", hasEnded: true)
                .contains("has ended")
        )
    }

    @Test func hasEndedUsesEndsAt() {
        let end = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        #expect(!MealCountdownChrome.hasEnded(endsAt: end, now: end.addingTimeInterval(-60)))
        #expect(MealCountdownChrome.hasEnded(endsAt: end, now: end))
    }
}
