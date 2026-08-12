import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealActivityPostClose")
struct MealActivityPostCloseTests {
    private let day = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
    ]
    private let evening = ISO8601DateFormatter().date(from: "2026-07-10T02:30:00Z")! // Thu 7:30 PM PDT

    @Test func lunchEndLinksSameDayDinner() {
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 870,
            timedPeriods: day,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Dinner")
        #expect(dest.date == nil)
    }

    @Test func dinnerEndLinksTomorrowBreakfast() {
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 1200,
            timedPeriods: day,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Breakfast")
        #expect(dest.date == "2026-07-10")
    }

    @Test func brunchEndLinksDinnerSameDay() {
        let brunchDay = [
            MealPeriodWindow(name: "Brunch", startMinutes: 600, endMinutes: 840),
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 840,
            timedPeriods: brunchDay,
            opensTomorrowPeriod: "Brunch",
            now: evening
        )
        #expect(dest.period == "Dinner")
        #expect(dest.date == nil)
    }

    @Test("Post-close keeps live Brunch for tomorrow — Status parity")
    func dinnerEndLinksTomorrowBrunchKeepsLiveName() {
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 1200,
            timedPeriods: day,
            opensTomorrowPeriod: "Brunch",
            now: evening
        )
        #expect(dest.period == "Brunch")
        #expect(dest.date == "2026-07-10")
        let chrome = MealCountdownChrome.islandBottom(
            period: "Dinner",
            hasEnded: true,
            postClosePeriod: dest.period,
            postCloseDate: dest.date,
            now: evening
        )
        #expect(chrome == "Dinner has ended — Brunch next")
        // Eat deep link still uses the Breakfast pill.
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: evening,
            postClosePeriod: dest.period,
            postCloseDate: dest.date,
            now: evening.addingTimeInterval(60)
        )
        #expect(link.period == "Breakfast")
        #expect(link.date == "2026-07-10")
    }

    @Test("Post-close keeps Limited Dinner for same-day next")
    func lunchEndLinksLimitedDinnerKeepsLiveName() {
        let limited = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
            MealPeriodWindow(name: "Limited Dinner", startMinutes: 1020, endMinutes: 1140),
        ]
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 870,
            timedPeriods: limited,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Limited Dinner")
        #expect(
            MealCountdownChrome.lockStatus(
                period: "Lunch",
                hasEnded: true,
                postClosePeriod: dest.period
            ) == "Lunch has ended — Limited Dinner is next"
        )
        let link = MealActivityDeepLink.link(
            hallID: "brandywine",
            period: "Lunch",
            endsAt: evening,
            postClosePeriod: dest.period,
            now: evening.addingTimeInterval(60)
        )
        #expect(link.period == "Dinner")
    }

    @Test func noNextAndNoTomorrowIsHallOnly() {
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 1200,
            timedPeriods: day,
            opensTomorrowPeriod: nil,
            now: evening
        )
        #expect(dest.period == nil)
        #expect(dest.date == nil)
    }

    @Test func breakfastOnlyBoardKeepsLastPostedNotTomorrow() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        let midday = ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z")! // Mon 8 AM PDT
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 630,
            timedPeriods: partial,
            opensTomorrowPeriod: "Breakfast",
            now: midday
        )
        #expect(dest.period == "Breakfast")
        #expect(dest.date == nil)
    }

    @Test func lunchWithoutDinnerKeepsLastPostedLunch() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        ]
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 870,
            timedPeriods: partial,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Lunch")
        #expect(dest.date == nil)
    }

    @Test func partialBoardContentStateDoesNotArmLegacyTomorrowDeepLink() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        let midday = ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z")! // Mon 8 AM PDT
        let breakfastEnd = ISO8601DateFormatter().date(from: "2026-07-13T18:30:00Z")! // Mon 11:30 AM PDT
        let afterClose = breakfastEnd.addingTimeInterval(60)
        let postClose = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 630,
            timedPeriods: partial,
            opensTomorrowPeriod: "Breakfast",
            now: midday
        )
        #expect(postClose.period == "Breakfast")
        let stash = MealActivityPostClose.contentOpensTomorrowPeriod(
            postClose: postClose,
            hallOpensTomorrowPeriod: "Breakfast"
        )
        #expect(stash == nil)
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Breakfast",
            endsAt: breakfastEnd,
            postClosePeriod: postClose.period,
            postCloseDate: postClose.date,
            opensTomorrowPeriod: stash,
            now: afterClose
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == "Breakfast")
        #expect(link.date == nil)
    }

    @Test func contentOpensTomorrowClearedEvenWhenPostCloseBakesTomorrow() {
        let dest = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 1200,
            timedPeriods: day,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(dest.period == "Breakfast")
        #expect(
            MealActivityPostClose.contentOpensTomorrowPeriod(
                postClose: dest,
                hallOpensTomorrowPeriod: "Breakfast"
            ) == nil
        )
    }

    @Test func needsRefreshWhenBoardGainsNextMeal() {
        let breakfastOnly = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
        ]
        let withLunch = breakfastOnly + [
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        ]
        let baked = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 630,
            timedPeriods: breakfastOnly,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(baked.period == "Breakfast")
        let fresh = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 630,
            timedPeriods: withLunch,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(fresh.period == "Lunch")
        #expect(
            MealActivityPostClose.needsRefresh(
                currentPeriod: baked.period,
                currentDate: baked.date,
                fresh: fresh
            )
        )
        #expect(
            !MealActivityPostClose.needsRefresh(
                currentPeriod: fresh.period,
                currentDate: fresh.date,
                fresh: fresh
            )
        )
        #expect(
            MealCountdownChrome.islandBottom(
                period: "Breakfast",
                hasEnded: true,
                postClosePeriod: fresh.period,
                postCloseDate: fresh.date
            ) == "Breakfast has ended — Lunch is next"
        )
    }

    @Test func lunchWithoutDinnerUpgradesWhenDinnerPublishes() {
        let partial = [
            MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),
            MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
        ]
        let full = partial + [
            MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
        ]
        let baked = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 870,
            timedPeriods: partial,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(baked.period == "Lunch")
        let fresh = MealActivityPostClose.destination(
            currentPeriodEndMinutes: 870,
            timedPeriods: full,
            opensTomorrowPeriod: "Breakfast",
            now: evening
        )
        #expect(fresh.period == "Dinner")
        #expect(
            MealActivityPostClose.needsRefresh(
                currentPeriod: baked.period,
                currentDate: baked.date,
                fresh: fresh
            )
        )
    }

    @Test func trackedPeriodEndMinutesMatchesLiveName() {
        let limited = [
            MealPeriodWindow(name: "Limited Dinner", startMinutes: 1020, endMinutes: 1140),
        ]
        #expect(
            MealActivityPostClose.trackedPeriodEndMinutes(
                trackedPeriod: "Limited Dinner",
                timedPeriods: limited
            ) == 1140
        )
        #expect(
            MealActivityPostClose.trackedPeriodEndMinutes(
                trackedPeriod: "Dinner",
                timedPeriods: limited
            ) == 1140
        )
    }
}

@Suite("MealActivityDeepLink")
struct MealActivityDeepLinkTests {
    /// Thursday 2026-07-09 7:30 PM Pacific — Dinner still live, ends 8 PM.
    private let sevenThirty = ISO8601DateFormatter().date(from: "2026-07-10T02:30:00Z")!
    private let eightPM = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
    private let eightOhOne = ISO8601DateFormatter().date(from: "2026-07-10T03:01:00Z")!

    @Test func liveLinksTodaysMealPill() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-10",
            now: sevenThirty
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == "Dinner")
        #expect(link.date == nil)
    }

    @Test func afterCloseUsesSameDayPostClose() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Lunch",
            endsAt: eightPM,
            postClosePeriod: "Dinner",
            postCloseDate: nil,
            opensTomorrowPeriod: "Breakfast",
            now: eightOhOne
        )
        #expect(link.period == "Dinner")
        #expect(link.date == nil)
    }

    @Test func afterCloseUsesTomorrowPostClose() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-10",
            now: eightOhOne
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == "Breakfast")
        #expect(link.date == "2026-07-10")
    }

    @Test func legacyOpensTomorrowFallback() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            opensTomorrowPeriod: "Breakfast",
            now: eightOhOne
        )
        #expect(link.period == "Breakfast")
        #expect(link.date == "2026-07-10")
    }

    @Test func afterCloseWithoutDestinationIsHallOnly() {
        let link = MealActivityDeepLink.link(
            hallID: "anteatery",
            period: "Dinner",
            endsAt: eightPM,
            now: eightOhOne
        )
        #expect(link.hall == "anteatery")
        #expect(link.period == nil)
        #expect(link.date == nil)
    }

    @Test func limitedDinnerCanonicalizesWhileLive() {
        let link = MealActivityDeepLink.link(
            hallID: "brandywine",
            period: "Limited Dinner",
            endsAt: eightPM,
            postClosePeriod: "Breakfast",
            now: sevenThirty
        )
        #expect(link.period == "Dinner")
    }
}

@Suite("MealCountdownChrome")
struct MealCountdownChromeTests {
    @Test func lockAndIslandFlipAfterEnd() {
        #expect(
            MealCountdownChrome.lockStatus(period: "Dinner", hasEnded: false) == "Dinner ends in"
        )
        #expect(
            MealCountdownChrome.lockStatus(period: "Dinner", hasEnded: true) == "Dinner has ended"
        )
        #expect(
            MealCountdownChrome.islandBottom(period: "Lunch", hasEnded: false)
                .contains("wrapping up")
        )
        #expect(
            MealCountdownChrome.islandBottom(
                period: "Lunch",
                hasEnded: true,
                postClosePeriod: "Dinner"
            ) == "Lunch has ended — Dinner is next"
        )
        #expect(
            MealCountdownChrome.lockStatus(
                period: "Lunch",
                hasEnded: true,
                postClosePeriod: "Dinner"
            ) == "Lunch has ended — Dinner is next"
        )
    }

    @Test func islandBottomAwaitingSamePeriodMatchesStatus() {
        #expect(
            MealCountdownChrome.islandBottom(
                period: "Breakfast",
                hasEnded: true,
                postClosePeriod: "Breakfast"
            ) == "Breakfast has ended — more meals post later"
        )
        #expect(
            MealCountdownChrome.lockStatus(
                period: "Lunch",
                hasEnded: true,
                postClosePeriod: "Lunch"
            ) == "Lunch has ended — more meals post later"
        )
    }

    @Test func islandBottomTomorrowNamesMealNotSeeWhatsNext() {
        // Thursday 9:00 PM Pacific — tomorrow is Friday 2026-07-10.
        let thursdayEvening = ISO8601DateFormatter().date(from: "2026-07-10T04:00:00Z")!
        let island = MealCountdownChrome.islandBottom(
            period: "Dinner",
            hasEnded: true,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-10",
            now: thursdayEvening
        )
        let lock = MealCountdownChrome.lockStatus(
            period: "Dinner",
            hasEnded: true,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-10",
            now: thursdayEvening
        )
        #expect(island == "Dinner has ended — Breakfast next")
        #expect(lock == island)
    }

    @Test("Fri→Mon Island linger names weekday like Status")
    func islandBottomBeyondTomorrowNamesWeekday() {
        // Friday 10:00 PM Pacific — Monday board is beyond tomorrow.
        let fridayNight = ISO8601DateFormatter().date(from: "2026-07-11T05:00:00Z")!
        let island = MealCountdownChrome.islandBottom(
            period: "Dinner",
            hasEnded: true,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-13",
            now: fridayNight
        )
        let lock = MealCountdownChrome.lockStatus(
            period: "Dinner",
            hasEnded: true,
            postClosePeriod: "Breakfast",
            postCloseDate: "2026-07-13",
            now: fridayNight
        )
        #expect(island == "Dinner has ended — Breakfast Monday")
        #expect(lock == island)
    }

    @Test("Fri→Mon linger keeps live Brunch like Status")
    func islandBottomBeyondTomorrowKeepsBrunch() {
        let fridayNight = ISO8601DateFormatter().date(from: "2026-07-11T05:00:00Z")!
        #expect(
            MealCountdownChrome.islandBottom(
                period: "Dinner",
                hasEnded: true,
                postClosePeriod: "Brunch",
                postCloseDate: "2026-07-13",
                now: fridayNight
            ) == "Dinner has ended — Brunch Monday"
        )
    }

    @Test func islandBottomHallOnlyDropsSeeWhatsNext() {
        #expect(
            MealCountdownChrome.islandBottom(period: "Dinner", hasEnded: true)
                == "Dinner has ended"
        )
        #expect(
            MealCountdownChrome.islandBottom(period: "", hasEnded: true)
                == "This meal has ended"
        )
        #expect(
            MealCountdownChrome.lockStatus(period: "", hasEnded: true)
                == "Meal has ended"
        )
    }

    @Test func hasEndedUsesEndsAt() {
        let end = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        #expect(!MealCountdownChrome.hasEnded(endsAt: end, now: end.addingTimeInterval(-60)))
        #expect(MealCountdownChrome.hasEnded(endsAt: end, now: end))
    }
}

@Suite("MealActivitySync")
struct MealActivitySyncTests {
    @Test func endedIsNotLive() {
        let end = ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
        #expect(MealActivitySync.isLive(endsAt: end, now: end.addingTimeInterval(-1)))
        #expect(!MealActivitySync.isLive(endsAt: end, now: end))
    }
}
