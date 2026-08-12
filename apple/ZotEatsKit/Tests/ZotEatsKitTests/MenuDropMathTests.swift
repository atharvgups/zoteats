import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MenuDropMath")
struct MenuDropMathTests {
    @Test func unpublishedDaysAreOutsideRange() {
        let upcoming = ["2026-08-12", "2026-08-13", "2026-08-14", "2026-08-15"]
        let pending = MenuDropMath.unpublishedDays(
            upcoming: upcoming,
            earliest: "2026-08-11",
            latest: "2026-08-13"
        )
        #expect(pending == Set(["2026-08-14", "2026-08-15"]))
    }

    @Test func newlyDroppedFiresOnce() {
        let previous: Set = ["2026-08-14", "2026-08-15"]
        let nowPublished: Set = ["2026-08-12", "2026-08-13", "2026-08-14"]
        let notified: Set = ["2026-08-13"]
        let fresh = MenuDropMath.newlyDroppedDays(
            previouslyUnpublished: previous,
            nowPublished: nowPublished,
            alreadyNotified: notified
        )
        #expect(fresh == Set(["2026-08-14"]))
    }

    @Test func emptyPreviousMeansNoSpamOnFirstCheck() {
        let fresh = MenuDropMath.newlyDroppedDays(
            previouslyUnpublished: [],
            nowPublished: ["2026-08-12", "2026-08-13"],
            alreadyNotified: []
        )
        #expect(fresh.isEmpty)
    }

    @Test func overnightPublishStillNotifiesWhenDayBecomesToday() {
        // Seeded as unpublished tomorrow; after midnight that ISO is today and
        // now inside /dateRange — must still fire once.
        let pending: Set = ["2026-08-13", "2026-08-15"]
        let nowPublished: Set = ["2026-08-13", "2026-08-14"] // today + tomorrow
        let fresh = MenuDropMath.newlyDroppedDays(
            previouslyUnpublished: pending,
            nowPublished: nowPublished,
            alreadyNotified: []
        )
        #expect(fresh == Set(["2026-08-13"]))
    }

    @Test func alreadyNotifiedTodayDoesNotSpam() {
        let pending: Set = ["2026-08-13"]
        let fresh = MenuDropMath.newlyDroppedDays(
            previouslyUnpublished: pending,
            nowPublished: ["2026-08-13"],
            alreadyNotified: ["2026-08-13"]
        )
        #expect(fresh.isEmpty)
    }
}
