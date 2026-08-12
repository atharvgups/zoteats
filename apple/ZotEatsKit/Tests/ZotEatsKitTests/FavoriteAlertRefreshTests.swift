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
        // Monday 7:00 AM Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let lunch = UCITime.date(
            forMinutes: 11 * 60 + 15,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == lunch)
    }

    @Test func middayAimsPreDinner() {
        // Monday noon Pacific.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let dinner = UCITime.date(
            forMinutes: 16 * 60 + 15,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == dinner)
    }

    @Test func afterDinnerAimsTomorrowBreakfast() {
        // Monday 5:00 PM Pacific — past 4:15 dinner aim.
        let now = ISO8601DateFormatter().date(from: "2026-07-14T00:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let tomorrowBreakfast = UCITime.date(
            forMinutes: 6 * 60 + 45,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == tomorrowBreakfast)
    }

    @Test func skipsAimInsideLeadWindow() {
        // Monday 11:00 AM — 11:15 is only 15m away (< 30m lead) → dinner.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:00:00Z")!
        let preferred = FavoriteAlertRefresh.preferredBeginDate(now: now)
        let dinner = UCITime.date(
            forMinutes: 16 * 60 + 15,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(preferred == dinner)
    }

    @Test func earliestBeginDateFloorsAtOneHour() {
        // Monday 10:00 AM — preferred is 11:15; above the 1h floor.
        let ten = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
        let lunch = FavoriteAlertRefresh.preferredBeginDate(now: ten)
        #expect(FavoriteAlertRefresh.earliestBeginDate(now: ten) == lunch)
        #expect(lunch == ten.addingTimeInterval(75 * 60)) // 11:15

        // Just after a fire with preferred far out — still ≥ now+1h.
        let eleven = ISO8601DateFormatter().date(from: "2026-07-13T18:00:00Z")!
        let earliest = FavoriteAlertRefresh.earliestBeginDate(now: eleven)
        #expect(earliest >= eleven.addingTimeInterval(60 * 60))
        #expect(earliest == FavoriteAlertRefresh.preferredBeginDate(now: eleven))
    }
}
