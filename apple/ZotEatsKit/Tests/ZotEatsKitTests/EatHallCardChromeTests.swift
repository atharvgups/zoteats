import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallCardChrome")
struct EatHallCardChromeTests {
    @Test func oasisStaysComingSoon() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: true,
                state: .open(period: "Lunch", closesAt: 900),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ) == "Coming Soon"
        )
    }

    @Test func openShowsMealName() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .open(period: "Lunch", closesAt: 900),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ) == "Lunch"
        )
    }

    @Test func laterTodayIsMealNameOnly() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .openingLater(period: "Dinner", opensAt: 990),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ) == "Dinner"
        )
    }

    @Test func closedShowsNextMealName() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowPeriod: "Breakfast",
                opensNextPeriod: nil
            ) == "Breakfast"
        )
    }

    @Test func statusNeverLongerThanComingSoon() {
        let samples = [
            EatHallCardChrome.statusText(
                comingSoon: true,
                state: .unknown,
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .openingLater(period: "Breakfast", opensAt: 420),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowPeriod: "Breakfast",
                opensNextPeriod: nil
            ),
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .unknown,
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ),
        ]
        let cap = OasisComingSoonCopy.cardStatus.count
        for text in samples {
            #expect(text.count <= cap)
            #expect(!text.contains("…"))
        }
    }

    @Test func closedWithNoNextIsClosed() {
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
