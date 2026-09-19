import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealActivityLinger")
struct MealActivityLingerTests {
    @Test func staleAndDismissalMatchThirtyMinutesPastEnd() {
        let ends = Date(timeIntervalSince1970: 1_800_000_000)
        let expected = ends.addingTimeInterval(30 * 60)
        #expect(MealActivityLinger.staleDate(endsAt: ends) == expected)
        #expect(MealActivityLinger.dismissalDate(endsAt: ends) == expected)
        #expect(MealActivityLinger.lingerInterval == 30 * 60)
    }

    @Test func shouldDismissOnlyAfterLinger() {
        let ends = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!MealActivityLinger.shouldDismiss(endsAt: ends, now: ends))
        #expect(!MealActivityLinger.shouldDismiss(
            endsAt: ends,
            now: ends.addingTimeInterval(30 * 60 - 1)
        ))
        #expect(MealActivityLinger.shouldDismiss(
            endsAt: ends,
            now: ends.addingTimeInterval(30 * 60)
        ))
        #expect(MealActivityLinger.shouldDismiss(
            endsAt: ends,
            now: ends.addingTimeInterval(2 * 60 * 60)
        ))
    }

    @Test func isLingeringBetweenEndAndDismissal() {
        let ends = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!MealActivityLinger.isLingering(endsAt: ends, now: ends.addingTimeInterval(-1)))
        #expect(MealActivityLinger.isLingering(endsAt: ends, now: ends))
        #expect(MealActivityLinger.isLingering(
            endsAt: ends,
            now: ends.addingTimeInterval(15 * 60)
        ))
        #expect(!MealActivityLinger.isLingering(
            endsAt: ends,
            now: ends.addingTimeInterval(30 * 60)
        ))
    }
}
