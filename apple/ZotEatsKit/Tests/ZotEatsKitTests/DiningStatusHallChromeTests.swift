import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusHallChrome")
struct DiningStatusHallChromeTests {
    private let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT
    private var nowMinutes: Int { UCITime.nowMinutes(now: now) }

    @Test func openUsesPeriodAndClosesCountdown() {
        let resolved = DiningStatusHallChrome.resolve(
            state: .open(period: "Dinner", closesAt: 1200),
            todayHours: nil,
            opensTomorrowAtMinutes: 435,
            opensTomorrowPeriod: "Breakfast",
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.statusText == "Dinner")
        #expect(resolved.countdownKind == .closes)
        #expect(resolved.countdownEnd == UCITime.date(forMinutes: 1200, nowMinutes: nowMinutes, now: now))
    }

    @Test func openingLaterUsesPeriodAndOpensCountdown() {
        let resolved = DiningStatusHallChrome.resolve(
            state: .openingLater(period: "Dinner", opensAt: 990),
            todayHours: nil,
            opensTomorrowAtMinutes: nil,
            opensTomorrowPeriod: nil,
            nowMinutes: 900,
            now: now
        )
        #expect(resolved.statusText == "Dinner")
        #expect(resolved.countdownKind == .opens)
    }

    @Test func closedForTodaySaysMealTomorrowNotBareMeal() {
        let resolved = DiningStatusHallChrome.resolve(
            state: .closedForToday,
            todayHours: nil,
            opensTomorrowAtMinutes: 7 * 60 + 15,
            opensTomorrowPeriod: "Breakfast",
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.statusText == "Breakfast tomorrow")
        #expect(resolved.countdownKind == .opens)
        #expect(
            resolved.countdownEnd
                == UCITime.date(forMinutes: 7 * 60 + 15, nowMinutes: nowMinutes, now: now)
        )
    }

    @Test func closedWithoutTomorrow() {
        let resolved = DiningStatusHallChrome.resolve(
            state: .closedForToday,
            todayHours: nil,
            opensTomorrowAtMinutes: nil,
            opensTomorrowPeriod: nil,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.statusText == "Closed for today")
        #expect(resolved.countdownEnd == nil)
    }
}
