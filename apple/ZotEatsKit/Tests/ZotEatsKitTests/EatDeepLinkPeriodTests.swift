import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDeepLinkPeriod")
struct EatDeepLinkPeriodTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let available = ["Breakfast", "Lunch", "Dinner", "All Day"]

    @Test("After hours clears Dinner deeplink")
    func afterHoursClearsDinner() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Dinner",
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 1300,
                browsingFutureDay: false
            ) == nil
        )
    }

    @Test("Live Lunch deeplink stays Lunch")
    func liveLunchKept() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Lunch",
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 700,
                browsingFutureDay: false
            ) == "Lunch"
        )
    }

    @Test("Ended Lunch at mid-afternoon falls through to Dinner")
    func endedLunchFallsToDinner() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Lunch",
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 900,
                browsingFutureDay: false
            ) == "Dinner"
        )
    }

    @Test("Upcoming Dinner deeplink before open is kept")
    func upcomingDinnerKept() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Dinner",
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 900,
                browsingFutureDay: false
            ) == "Dinner"
        )
    }

    @Test("Future-day browse keeps requested pill")
    func futureDayKeepsPill() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: "Breakfast",
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 1300,
                browsingFutureDay: true
            ) == "Breakfast"
        )
    }

    @Test("Future-day nil request snaps first primary pill")
    func futureDayNilRequestSnapsBreakfast() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: nil,
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 1300,
                browsingFutureDay: true
            ) == "Breakfast"
        )
    }

    @Test("Nil request picks live meal")
    func nilPicksLive() {
        #expect(
            EatDeepLinkPeriod.resolve(
                requested: nil,
                availablePeriods: available,
                timedPeriods: day,
                nowMinutes: 700,
                browsingFutureDay: false
            ) == "Lunch"
        )
    }
}
