import Testing
@testable import ZotEatsKit

@Suite("EatPostedDays")
struct EatPostedDaysTests {
    private let candidates: [(isoDate: String, label: String)] = [
        ("2026-08-17", "Today"),
        ("2026-08-18", "Tomorrow"),
        ("2026-08-19", "Wed 19"),
        ("2026-08-20", "Thu 20"),
    ]

    @Test func todayAlwaysShowsWhileProbeIsPending() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: nil
        )
        #expect(days.map(\.isoDate) == ["2026-08-17"])
    }

    @Test func skipsEmptyMidweekWhenThursdayIsPosted() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-17", "2026-08-20"]
        )
        #expect(days.map(\.isoDate) == ["2026-08-17", "2026-08-20"])
        #expect(days.map(\.label) == ["Today", "Thu 20"])
    }

    @Test func keepsTomorrowWhenItHasABoard() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-18"]
        )
        #expect(days.map(\.isoDate) == ["2026-08-17", "2026-08-18"])
    }
}

@Suite("EatBrowseEmptyCopy")
struct EatBrowseEmptyCopyTests {
    @Test func futureDayAvoidsDateStripJargon() {
        let msg = EatBrowseEmptyCopy.message(period: "Breakfast", browsingFutureDay: true)
        #expect(!msg.localizedCaseInsensitiveContains("date strip"))
        #expect(msg.localizedCaseInsensitiveContains("another day"))
    }

    @Test func todayNamesTheMeal() {
        #expect(
            EatBrowseEmptyCopy.message(period: "Lunch", browsingFutureDay: false)
                .contains("lunch")
        )
    }
}
