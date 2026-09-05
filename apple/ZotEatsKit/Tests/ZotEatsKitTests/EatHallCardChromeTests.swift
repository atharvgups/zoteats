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

    @Test func laterTodaySaysSoon() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .openingLater(period: "Dinner", opensAt: 990),
                opensTomorrowPeriod: nil,
                opensNextPeriod: nil
            ) == "Dinner soon"
        )
    }

    @Test func closedShowsNextMeal() {
        #expect(
            EatHallCardChrome.statusText(
                comingSoon: false,
                state: .closedForToday,
                opensTomorrowPeriod: "Breakfast",
                opensNextPeriod: nil
            ) == "Breakfast next"
        )
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
