import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallCardChrome")
struct EatHallCardChromeTests {
    @Test func oasisStaysComingSoon() {
        let status = EatHallCardChrome.status(
            comingSoon: true,
            state: .open(period: "Lunch", closesAt: 900),
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Coming Soon")
        #expect(status.secondary == nil)
    }

    @Test func openShowsMealNameOnly() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .open(period: "Lunch", closesAt: 900),
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Lunch")
        #expect(status.secondary == nil)
        #expect(status.accessibilityLine == "Lunch")
    }

    @Test func laterTodayShowsUpcomingMealName() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .openingLater(period: "Dinner", opensAt: 990),
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Dinner")
        #expect(status.secondary == nil)
    }

    @Test func closedShowsClosedWithoutNextMealEssay() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowPeriod: "Breakfast",
            opensNextPeriod: nil
        )
        #expect(status.primary == "Closed")
        #expect(status.secondary == nil)
    }

    @Test func statusLinesStayShort() {
        let samples = [
            EatHallCardChrome.status(
                comingSoon: true,
                state: .unknown,
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .openingLater(period: "Breakfast", opensAt: 420),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowPeriod: "Breakfast",
                opensNextPeriod: nil
            ),
            EatHallCardChrome.status(
                comingSoon: false,
                state: .unknown,
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
        ]
        let cap = OasisComingSoonCopy.cardStatus.count
        for status in samples {
            #expect(status.primary.count <= cap)
            #expect(status.secondary == nil)
            #expect(!status.accessibilityLine.contains("…"))
        }
    }

    @Test func closedWithNoNextIsClosed() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Closed")
        #expect(status.secondary == nil)
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ) == "Closed"
        )
    }
}
