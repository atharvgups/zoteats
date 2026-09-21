import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallCardChrome")
struct EatHallCardChromeTests {
    @Test func oasisStaysComingSoon() {
        let status = EatHallCardChrome.status(
            comingSoon: true,
            state: .open(period: "Lunch", closesAt: 900),
            opensTomorrowAtMinutes: nil
        )
        #expect(status.primary == "Coming Soon")
        #expect(status.secondary == nil)
    }

    @Test func openShowsUntilClock() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .open(period: "Lunch", closesAt: 14 * 60 + 30),
            opensTomorrowAtMinutes: 7 * 60 + 15
        )
        #expect(status.primary == "Open · until 2:30 PM")
        #expect(status.secondary == nil)
        #expect(status.accessibilityLine == "Open · until 2:30 PM")
    }

    @Test func openDropsZeroMinutes() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .open(period: "Dinner", closesAt: 20 * 60),
            opensTomorrowAtMinutes: nil
        )
        #expect(status.primary == "Open · until 8 PM")
    }

    @Test func laterTodayShowsClosedOpensClock() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .openingLater(period: "Dinner", opensAt: 17 * 60),
            opensTomorrowAtMinutes: nil
        )
        #expect(status.primary == "Closed · opens 5 PM")
        #expect(status.secondary == nil)
    }

    @Test func closedShowsNextOpenClock() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowAtMinutes: 7 * 60 + 15
        )
        #expect(status.primary == "Closed · opens 7:15 AM")
        #expect(status.secondary == nil)
    }

    @Test func closedNextWeekdayStaysCompact() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowAtMinutes: nil,
            opensNextAtMinutes: 7 * 60 + 15,
            opensNextWeekday: "Monday"
        )
        #expect(status.primary == "Closed · Mon 7:15 AM")
    }

    @Test func awaitingMoreMealsIsCompact() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .awaitingMoreMeals,
            opensTomorrowAtMinutes: 7 * 60 + 15
        )
        #expect(status.primary == "More later")
    }

    @Test func unknownIsNotPosted() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .unknown,
            opensTomorrowAtMinutes: nil
        )
        #expect(status.primary == "Not posted")
    }

    @Test func statusLinesStayOneCompactLine() {
        let samples = [
            EatHallCardChrome.status(
                comingSoon: true,
                state: .unknown,
                opensTomorrowAtMinutes: nil
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .openingLater(period: "Breakfast", opensAt: 7 * 60 + 15),
                opensTomorrowAtMinutes: nil
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowAtMinutes: 7 * 60 + 15
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .unknown,
                opensTomorrowAtMinutes: nil
            ),
        ]
        for status in samples {
            #expect(!status.primary.contains("\n"))
            #expect(status.secondary == nil)
            #expect(!status.accessibilityLine.contains("…"))
            #expect(status.primary.count <= 28)
        }
    }

    @Test func closedWithNoNextIsClosed() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowAtMinutes: nil
        )
        #expect(status.primary == "Closed")
        #expect(status.secondary == nil)
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowAtMinutes: nil
            ) == "Closed"
        )
    }

    @Test func compactClockDropsZeroMinutes() {
        #expect(EatHallCardChrome.compactClock(minutes: 20 * 60) == "8 PM")
        #expect(EatHallCardChrome.compactClock(minutes: 7 * 60 + 15) == "7:15 AM")
        #expect(EatHallCardChrome.compactClock(minutes: 11 * 60) == "11 AM")
    }
}
