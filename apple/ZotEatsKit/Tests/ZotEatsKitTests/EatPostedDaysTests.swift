import Testing
@testable import ZotEatsKit

@Suite("EatPostedDays")
struct EatPostedDaysTests {
    private let candidates: [(isoDate: String, label: String)] = [
        ("2026-08-17", "Today"),
        ("2026-08-18", "Tomorrow"),
        ("2026-08-19", "Wed Aug 19"),
        ("2026-08-20", "Thu Aug 20"),
    ]

    @Test func todayAlwaysShowsWhileProbeIsPending() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: nil
        )
        #expect(days.map(\.isoDate) == ["2026-08-17"])
        #expect(days.allSatisfy { !$0.skipsAhead })
    }

    @Test func skipsEmptyMidweekWhenThursdayIsPosted() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-17", "2026-08-20"]
        )
        #expect(days.map(\.isoDate) == ["2026-08-17", "2026-08-20"])
        #expect(days.map(\.label) == ["Today", "Next · Thu Aug 20"])
        #expect(days[1].skipsAhead)
        #expect(days[1].accessibilityLabel.contains("Next posted"))
        #expect(EatPostedDays.skipsCalendarDays(from: "2026-08-17", to: "2026-08-20"))
    }

    @Test func keepsTomorrowWhenItHasABoard() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-18"]
        )
        #expect(days.map(\.isoDate) == ["2026-08-17", "2026-08-18"])
        #expect(days.map(\.label) == ["Today", "Tomorrow"])
        #expect(days.allSatisfy { !$0.skipsAhead })
    }

    @Test func laterDaysAfterTomorrowAreNotCalledNext() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-18", "2026-08-20"]
        )
        #expect(days.map(\.label) == ["Today", "Tomorrow", "Thu Aug 20"])
        #expect(days.map(\.skipsAhead) == [false, false, false])
    }

    @Test func browseCaptionNamesTheSkip() {
        #expect(
            EatPostedDays.browseCaption(
                period: "Brunch",
                prettyDate: "Thursday, Aug 20",
                skipsAhead: true
            ) == "Brunch • next posted · Thursday, Aug 20"
        )
        #expect(
            EatPostedDays.browseCaption(
                period: "Lunch",
                prettyDate: "Tuesday, Aug 18",
                skipsAhead: false
            ) == "Lunch • Tuesday, Aug 18"
        )
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
