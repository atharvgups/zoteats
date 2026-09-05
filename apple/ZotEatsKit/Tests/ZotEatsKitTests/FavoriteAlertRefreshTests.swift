import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FavoriteAlertRefresh")
struct FavoriteAlertRefreshTests {
    @Test func beforeBreakfastAimsMorningSlot() {
        // Monday 2026-07-13, 5:00 AM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T12:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let breakfast = UCITime.date(
            forMinutes: 6 * 60 + 45,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == breakfast)
    }

    @Test func afterBreakfastAimsPreLunch() {
        // Monday 7:00 AM Pacific — early Lunch publish probe (before 11:00 open).
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let lunchProbe = UCITime.date(
            forMinutes: 10 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == lunchProbe)
    }

    @Test func middayAimsPreDinner() {
        // Monday noon Pacific — early Dinner publish probe (before 4:00 open).
        let now = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let dinnerProbe = UCITime.date(
            forMinutes: 15 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == dinnerProbe)
    }

    @Test func afterDinnerAimsEveningMenuDrop() {
        // Monday 5:00 PM Pacific — past 4:15 dinner aim → 8:00 PM menu-drop slot.
        let now = ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let evening = UCITime.date(
            forMinutes: 20 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == evening)
    }

    @Test func afterEveningAimsTomorrowBreakfast() {
        // Monday 8:30 PM Pacific — past 8:00 evening aim.
        let now = ISO8601DateFormatter().date(from: "2026-07-14T03:30:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let tomorrowBreakfast = UCITime.date(
            forMinutes: 6 * 60 + 45,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == tomorrowBreakfast)
    }

    @Test func skipsAimInsideLeadWindow() {
        // Monday 11:00 AM — 11:15 is only 15m away (< 30m lead) → early Dinner probe.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let dinnerProbe = UCITime.date(
            forMinutes: 15 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == dinnerProbe)
    }

    @Test func earliestBeginDateFloorsAtOneHour() {
        // Monday 10:00 AM — preferred is 10:50; earliest still floors at now+1h.
        let ten = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
        let lunch = FavoriteAlertRefresh.preferredBeginDate(now: ten)
        #expect(lunch == ten.addingTimeInterval(50 * 60)) // 10:50
        #expect(
            FavoriteAlertRefresh.earliestBeginDate(now: ten)
                == ten.addingTimeInterval(60 * 60)
        )

        // Just after a fire with preferred far out — still ≥ now+1h.
        let eleven = ISO8601DateFormatter().date(from: "2026-07-13T18:00:00Z")!
        let earliest = FavoriteAlertRefresh.earliestBeginDate(now: eleven)
        #expect(earliest >= eleven.addingTimeInterval(60 * 60))
        #expect(earliest == FavoriteAlertRefresh.preferredBeginDate(now: eleven))
    }

    @Test func wrapUpAimBeatsFixedDinnerAim() {
        // Monday noon — Lunch wrap-up at 825 (1:45 PM) is sooner than 4:15 dinner aim.
        let noon = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")!
        let wrapUp = 870 - 45
        let preferred = FavoriteAlertRefresh.preferredBeginDate(
            now: noon,
            extraAimMinutes: [wrapUp]
        )
        let expected = UCITime.date(
            forMinutes: wrapUp,
            nowMinutes: UCITime.nowMinutes(now: noon),
            now: noon
        )
        #expect(preferred == expected)
    }

    @Test func wrapUpEarliestBeginSkipsOneHourFloor() {
        // Monday 1:00 PM — Lunch wrap-up at 1:45 is preferred; must not push to 2:00.
        let onePM = ISO8601DateFormatter().date(from: "2026-07-13T20:00:00Z")!
        let wrapUp = 870 - 45
        let earliest = FavoriteAlertRefresh.earliestBeginDate(
            now: onePM,
            extraAimMinutes: [wrapUp]
        )
        let expected = UCITime.date(
            forMinutes: wrapUp,
            nowMinutes: UCITime.nowMinutes(now: onePM),
            now: onePM
        )
        #expect(earliest == expected)
        #expect(earliest < onePM.addingTimeInterval(60 * 60))
    }

    @Test func allowImmediateSchedulesAboutOneMinuteOut() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let earliest = FavoriteAlertRefresh.earliestBeginDate(now: now, allowImmediate: true)
        #expect(earliest == now.addingTimeInterval(60))
    }

    @Test func brunchOpenAimBeatsFixedPreLunch() {
        // Monday 8:00 AM — live Brunch at 10:00 beats fixed 11:15.
        let eight = ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z")!
        let brunchOpen = 10 * 60
        let preferred = FavoriteAlertRefresh.preferredBeginDate(
            now: eight,
            extraAimMinutes: [brunchOpen]
        )
        let expected = UCITime.date(
            forMinutes: brunchOpen,
            nowMinutes: UCITime.nowMinutes(now: eight),
            now: eight
        )
        #expect(preferred == expected)
    }

    @Test func lunchOpenAimBeatsLateFixedPreLunch() {
        // Monday 10:55 AM — live Lunch at 11:00 beats fixed 11:15 (after open).
        let tenFiftyFive = ISO8601DateFormatter().date(from: "2026-07-13T17:55:00Z")!
        let lunchOpen = 11 * 60
        let preferred = FavoriteAlertRefresh.preferredBeginDate(
            now: tenFiftyFive,
            extraAimMinutes: [lunchOpen]
        )
        let expected = UCITime.date(
            forMinutes: lunchOpen,
            nowMinutes: UCITime.nowMinutes(now: tenFiftyFive),
            now: tenFiftyFive
        )
        #expect(preferred == expected)
    }

    @Test func awaitingPublishProbeShortLeadBeforeLunchOpen() {
        // Monday 10:35 — fixed 10:50 is inside 30m lead; short-lead extra probe wins.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:35:00Z")!
        let lastChance = 10 * 60 + 50
        let preferred = FavoriteAlertRefresh.preferredBeginDate(
            now: now,
            extraAimMinutes: [lastChance, 11 * 60 + 15]
        )
        let expected = UCITime.date(
            forMinutes: lastChance,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == expected)
        let earliest = FavoriteAlertRefresh.earliestBeginDate(
            now: now,
            extraAimMinutes: [lastChance, 11 * 60 + 15]
        )
        #expect(earliest == max(expected, now.addingTimeInterval(60)))
        #expect(earliest < now.addingTimeInterval(60 * 60))
    }

    @Test func awaitingPublishProbeShortLeadBeforeDinnerOpen() {
        // Monday 3:00 PM — short-lead 3:30 Dinner probe beats fixed 4:15 + 1h floor.
        let three = ISO8601DateFormatter().date(from: "2026-07-13T22:00:00Z")!
        let earlyDinner = 15 * 60 + 30
        let earliest = FavoriteAlertRefresh.earliestBeginDate(
            now: three,
            extraAimMinutes: [earlyDinner, 16 * 60 + 15]
        )
        let expected = UCITime.date(
            forMinutes: earlyDinner,
            nowMinutes: UCITime.nowMinutes(now: three),
            now: three
        )
        #expect(earliest == max(expected, three.addingTimeInterval(60)))
        #expect(earliest < three.addingTimeInterval(60 * 60))
    }

    @Test func emptyBoardPublishProbesShortLeadLikePartialBoards() {
        // Monday 10:05 — empty board should expose the same upcoming probes BG uses.
        let nowMinutes = 10 * 60 + 5
        #expect(
            DiningBoardPublish.shouldProbeForPublish(periods: [], nowMinutes: nowMinutes)
        )
        let probes = DiningBoardPublish.upcomingPublishProbeMinutes(nowMinutes: nowMinutes)
        #expect(probes.contains(10 * 60 + 30))
        #expect(probes.contains(10 * 60 + 50))
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:05:00Z")!
        let earliest = FavoriteAlertRefresh.earliestBeginDate(
            now: now,
            extraAimMinutes: probes
        )
        let expected = UCITime.date(
            forMinutes: 10 * 60 + 30,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(earliest == max(expected, now.addingTimeInterval(60)))
        #expect(earliest < now.addingTimeInterval(60 * 60))
    }

    @Test func earlyDinnerOpenAimSkipsOneHourFloor() {
        // Monday 3:30 PM — Brandywine Dinner at 4:00 must not push to 4:30.
        let halfPastThree = ISO8601DateFormatter().date(from: "2026-07-13T22:30:00Z")!
        let dinnerOpen = 16 * 60
        let earliest = FavoriteAlertRefresh.earliestBeginDate(
            now: halfPastThree,
            extraAimMinutes: [dinnerOpen]
        )
        let expected = UCITime.date(
            forMinutes: dinnerOpen,
            nowMinutes: UCITime.nowMinutes(now: halfPastThree),
            now: halfPastThree
        )
        #expect(earliest == expected)
        #expect(earliest < halfPastThree.addingTimeInterval(60 * 60))
    }
}
