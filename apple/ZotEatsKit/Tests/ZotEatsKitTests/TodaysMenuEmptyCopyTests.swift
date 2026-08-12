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
            ) == "Dinner's done — Brunch tomorrow · 10:00 AM"
        )
    }

    @Test func afterHoursWithoutTomorrowKeepsFallback() {
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .glance
            ) == "Closed for today"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHours(
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .home
            ) == "Dinner's done — closed for today"
        )
    }

    @Test func eatAfterHoursNamesTomorrowWhenKnown() {
        #expect(
            TodaysMenuEmptyCopy.eatAfterHoursMessage(
                hallName: "The Anteatery",
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15
            ) == "The Anteatery is closed for tonight. Breakfast tomorrow · 7:15 AM."
        )
        #expect(
            TodaysMenuEmptyCopy.eatAfterHoursMessage(
                hallName: "Brandywine",
                opensTomorrowPeriod: "Brunch",
                opensTomorrowAtMinutes: 10 * 60
            ) == "Brandywine is closed for tonight. Brunch tomorrow · 10:00 AM."
        )
        #expect(
            TodaysMenuEmptyCopy.eatAfterHoursMessage(
                hallName: "Brandywine",
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil
            ) == "Brandywine is closed for tonight."
        )
    }

    @Test func upcomingEmptyNamesStartTime() {
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: false,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .glance,
                period: "Dinner",
                upcomingStartMinutes: 990
            ) == "Dinner starts at 4:30 PM"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: false,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .home,
                period: "Lunch",
                upcomingStartMinutes: 11 * 60
            ) == "Lunch starts at 11:00 AM — dishes post when it opens"
        )
    }

    @Test func awaitingMoreMealsBeatsTomorrowEmptyCopy() {
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                surface: .glance,
                awaitingMoreMeals: true
            ) == "More meals post later"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                surface: .home,
                awaitingMoreMeals: true
            ) == "More meals still posting today — pull to refresh"
        )
    }

    @Test func emptyBoardWithoutAfterHoursIsNotPostedNotClosed() {
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .glance,
                isAfterHours: false
            ) == "Menu not posted yet"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .home,
                isAfterHours: false
            ) == "No menu posted right now — check back at the next meal"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                surface: .glance,
                isAfterHours: false
            ) == "Menu not posted yet"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: "Breakfast",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                surface: .glance,
                isAfterHours: true
            ) == "Breakfast tomorrow · 7:15 AM"
        )
        #expect(
            TodaysMenuEmptyCopy.reason(
                periodIsEmpty: true,
                filtersEmptiedMenu: false,
                opensTomorrowPeriod: nil,
                opensTomorrowAtMinutes: nil,
                surface: .home,
                isAfterHours: true
            ) == "Dinner's done — closed for today"
        )
    }

    @Test func eatIdleEmptyHonorsAwaitingMoreMeals() {
        #expect(
            TodaysMenuEmptyCopy.eatIdleEmptyTitle(
                awaitingMoreMeals: true,
                afterHours: false
            ) == "More meals coming"
        )
        #expect(
            TodaysMenuEmptyCopy.eatIdleEmptyTitle(
                awaitingMoreMeals: false,
                afterHours: true
            ) == "Dinner's done"
        )
        #expect(
            TodaysMenuEmptyCopy.eatIdleEmptyTitle(
                awaitingMoreMeals: false,
                afterHours: false
            ) == "No menu yet"
        )
        #expect(
            TodaysMenuEmptyCopy.eatAwaitingMoreMealsMessage(hallName: "The Anteatery")
                == "The Anteatery already posted earlier meals — Lunch or Dinner often lands later. Pull to refresh."
        )
        #expect(
            TodaysMenuEmptyCopy.eatAwaitingMoreMealsMessage(hallName: "  ")
                == "This hall already posted earlier meals — Lunch or Dinner often lands later. Pull to refresh."
        )
    }

    @Test func tomorrowISOIsDayAfterToday() {
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT
        #expect(TodaysMenuEmptyCopy.tomorrowISO(now: now) == "2026-07-10")
    }

    @Test func afterHoursActionTitleMatchesJumpDay() {
        #expect(
            TodaysMenuEmptyCopy.afterHoursActionTitle(
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensNextWeekday: "Monday"
            ) == "See tomorrow"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHoursActionTitle(
                opensTomorrowAtMinutes: nil,
                opensNextWeekday: "Monday"
            ) == "See Monday"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHoursActionTitle(
                opensTomorrowAtMinutes: nil,
                opensNextWeekday: nil
            ) == nil
        )
    }

    @Test func afterHoursJumpISORequiresKnownOpen() {
        let now = ISO8601DateFormatter().date(from: "2026-07-10T05:00:00Z")! // Thu 10 PM PDT
        #expect(
            TodaysMenuEmptyCopy.afterHoursJumpISO(
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensNextDateISO: nil,
                opensNextDayOffset: nil,
                now: now
            ) == "2026-07-10"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHoursJumpISO(
                opensTomorrowAtMinutes: nil,
                opensNextDateISO: "2026-07-13",
                opensNextDayOffset: 3,
                now: now
            ) == "2026-07-13"
        )
        #expect(
            TodaysMenuEmptyCopy.afterHoursJumpISO(
                opensTomorrowAtMinutes: nil,
                opensNextDateISO: nil,
                opensNextDayOffset: nil,
                now: now
            ) == nil
        )
    }
}
