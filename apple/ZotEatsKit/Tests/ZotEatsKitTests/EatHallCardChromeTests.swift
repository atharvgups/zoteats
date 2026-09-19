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

    @Test func openShowsOpenAndMealName() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .open(period: "Lunch", closesAt: 900),
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Open")
        #expect(status.secondary == "Lunch")
        #expect(status.accessibilityLine == "Open, Lunch")
    }

    @Test func laterTodayIsSoonAndMealName() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .openingLater(period: "Dinner", opensAt: 990),
            opensTomorrowPeriod: nil,
            opensNextPeriod: nil
        )
        #expect(status.primary == "Soon")
        #expect(status.secondary == "Dinner")
    }

    @Test func closedShowsClosedAndNextMealName() {
        let status = EatHallCardChrome.status(
            comingSoon: false,
            state: .closedForToday,
            opensTomorrowPeriod: "Breakfast",
            opensNextPeriod: nil
        )
        #expect(status.primary == "Closed")
        #expect(status.secondary == "Breakfast")
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
            if let secondary = status.secondary {
                #expect(secondary.count <= cap)
            }
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
