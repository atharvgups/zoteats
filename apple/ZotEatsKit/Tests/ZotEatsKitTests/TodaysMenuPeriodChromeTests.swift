import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuPeriodChrome")
struct TodaysMenuPeriodChromeTests {
    private let now = ISO8601DateFormatter().date(from: "2026-07-13T20:00:00Z")! // Mon 1 PM PDT
    private var nowMinutes: Int { UCITime.nowMinutes(now: now) }

    @Test func servingUsesClosesCountdown() {
        let resolved = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: 870,
            upcomingStartMinutes: nil,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.kind == .closes)
        #expect(resolved.countdownEnd == UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now))
    }

    @Test func betweenMealsUsesOpensCountdown() {
        let resolved = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: nil,
            upcomingStartMinutes: 990,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.kind == .opens)
        #expect(resolved.countdownEnd == UCITime.date(forMinutes: 990, nowMinutes: nowMinutes, now: now))
    }

    @Test func afterHoursHasNoCountdown() {
        let resolved = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: nil,
            upcomingStartMinutes: nil,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(resolved.kind == nil)
        #expect(resolved.countdownEnd == nil)
    }

    @Test func awaitingMoreMealsHasNoCountdownUsesStatusCaption() {
        let resolved = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: nil,
            upcomingStartMinutes: nil,
            nowMinutes: nowMinutes,
            now: now,
            awaitingMoreMeals: true
        )
        #expect(resolved.kind == .awaitingMoreMeals)
        #expect(resolved.countdownEnd == nil)
        #expect(
            TodaysMenuPeriodChrome.awaitingCaption
                == TodaysMenuEmptyCopy.awaitingMoreMeals(surface: .glance)
        )
        #expect(TodaysMenuPeriodChrome.awaitingCaptionCompact == "more later")
    }

    @Test func liveOpenBeatsAwaitingFlag() {
        let resolved = TodaysMenuPeriodChrome.resolve(
            endsAtMinutes: 870,
            upcomingStartMinutes: nil,
            nowMinutes: nowMinutes,
            now: now,
            awaitingMoreMeals: true
        )
        #expect(resolved.kind == .closes)
    }
}
