import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuEmptyCopy")
struct TodaysMenuEmptyCopyTests {
    @Test func afterHoursWithTomorrowNamesMealAndTime() {
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                surface: .glance
            ) == "Breakfast tomorrow · 7:15 AM"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: "Brunch",
                opensTomorrowAtMinutes: 10 * 60,
                surface: .home
            ) == "Dinner's done — Breakfast tomorrow · 10:00 AM"
        )
    }

    @Test func afterHoursWithoutTomorrowKeepsFallback() {
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .glance
            ) == "See you at breakfast"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .home
            ) == "Dinner's done — breakfast posts overnight"
        )
    }
}
