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

    @Test func todayAndTomorrowShowWhileProbeIsPending() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: nil
        )
        #expect(days.map(\.isoDate) == [
            "2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20"
        ])
        #expect(days.map(\.label) == ["Today", "Tomorrow", "Wed 19", "Thu 20"])
        #expect(days.allSatisfy { !$0.skipsAhead })
        #expect(days.allSatisfy { $0.hasPostedMenu })
    }

    @Test func keepsUnpostedDaysSelectable() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-17", "2026-08-20"]
        )
        #expect(days.map(\.isoDate) == [
            "2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20"
        ])
        #expect(days.map(\.label).starts(with: ["Today", "Tomorrow"]) == true)
        #expect(days.first { $0.isoDate == "2026-08-19" }?.hasPostedMenu == false)
        #expect(days.first { $0.isoDate == "2026-08-20" }?.hasPostedMenu == true)
        #expect(days.first { $0.isoDate == "2026-08-19" }?.accessibilityLabel.contains("no menu") == true)
    }

    @Test func keepsTomorrowWhenItHasABoard() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-18"]
        )
        #expect(days.map(\.isoDate).starts(with: ["2026-08-17", "2026-08-18"]) == true)
        #expect(days.map(\.label).starts(with: ["Today", "Tomorrow"]) == true)
        #expect(days.count >= 2)
    }

    @Test func laterDaysAfterTomorrowAreNotCalledNext() {
        let days = EatPostedDays.visible(
            candidates: candidates,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-18", "2026-08-20"]
        )
        #expect(days.map(\.label).starts(with: ["Today", "Tomorrow"]) == true)
        #expect(days.contains { $0.isoDate == "2026-08-20" && $0.label == "Thu 20" })
    }

    @Test func jumpAfterTomorrowMarksNext() {
        let short: [(isoDate: String, label: String)] = [
            ("2026-08-17", "Today"),
            ("2026-08-18", "Tomorrow"),
            ("2026-08-20", "Thu Aug 20"),
        ]
        let days = EatPostedDays.visible(
            candidates: short,
            todayISO: "2026-08-17",
            postedISOs: ["2026-08-17", "2026-08-18", "2026-08-20"]
        )
        #expect(days.map(\.label) == ["Today", "Tomorrow", "Next · Thu 20"])
        #expect(days[2].skipsAhead)
    }

    @Test func horizonGrowsWithoutDumpingPastTheCap() {
        #expect(EatPostedDays.initialHorizonDays >= 14)
        #expect(EatPostedDays.extendedHorizon(21) == 35)
        #expect(EatPostedDays.extendedHorizon(EatPostedDays.maxHorizonDays) == EatPostedDays.maxHorizonDays)
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
        #expect(msg.localizedCaseInsensitiveContains("posted"))
    }

    @Test func todayNamesTheMeal() {
        #expect(
            EatBrowseEmptyCopy.message(period: "Lunch", browsingFutureDay: false)
                .contains("lunch")
        )
    }
}
