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

    @Test func awaitingMoreMealsHasNoTomorrowCountdown() {
        let midday = ISO8601DateFormatter().date(from: "2026-07-13T18:30:00Z")! // Mon 11:30 AM PDT
        let resolved = DiningStatusHallChrome.resolve(
            state: .awaitingMoreMeals,
            todayHours: nil,
            opensTomorrowAtMinutes: 7 * 60 + 15,
            opensTomorrowPeriod: "Breakfast",
            nowMinutes: UCITime.nowMinutes(now: midday),
            now: midday
        )
        #expect(resolved.statusText == "More meals post later")
        #expect(resolved.countdownEnd == nil)
        #expect(resolved.countdownKind == nil)
    }

    @Test func unknownSaysMenuNotPostedYetNeverEchoesTodayHours() {
        let resolved = DiningStatusHallChrome.resolve(
            state: .unknown,
            todayHours: "7:15 AM – 8:00 PM",
            opensTomorrowAtMinutes: 7 * 60 + 15,
            opensTomorrowPeriod: "Breakfast",
            nowMinutes: 9 * 60,
            now: now
        )
        #expect(resolved.statusText == "Menu not posted yet")
        #expect(resolved.countdownEnd == nil)
        #expect(resolved.countdownKind == nil)
    }

    @Test func emptyEveningClosedShowsNextOpenWeekday() {
        let friday = ISO8601DateFormatter().date(from: "2026-07-11T03:00:00Z")! // Fri 8 PM PDT
        let resolved = DiningStatusHallChrome.resolve(
            state: .closedForToday,
            todayHours: nil,
            opensTomorrowAtMinutes: nil,
            opensTomorrowPeriod: nil,
            nowMinutes: UCITime.nowMinutes(now: friday),
            now: friday,
            opensNextAtMinutes: 7 * 60 + 15,
            opensNextDayOffset: 3,
            opensNextWeekday: "Monday",
            opensNextPeriod: "Breakfast"
        )
        #expect(resolved.statusText == "Breakfast Monday")
        #expect(resolved.countdownKind == .opens)
    }
}
