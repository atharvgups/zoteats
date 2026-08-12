import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealCountdownAccessibilityLabel")
struct MealCountdownAccessibilityLabelTests {
    /// Thursday 2026-07-09 20:00:00 Pacific (PDT, UTC-7).
    private let eightPM: Date = {
        ISO8601DateFormatter().date(from: "2026-07-10T03:00:00Z")!
    }()

    /// Thursday 2026-07-09 14:00:00 Pacific.
    private let twoPM: Date = {
        ISO8601DateFormatter().date(from: "2026-07-09T21:00:00Z")!
    }()

    /// Friday 2026-07-10 00:00:00 Pacific.
    private let midnight: Date = {
        ISO8601DateFormatter().date(from: "2026-07-10T07:00:00Z")!
    }()

    @Test("Dinner ends at 8:00 PM Pacific")
    func dinnerAtEight() {
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "Dinner",
                endsAt: eightPM
            ) == "The Anteatery, Dinner ends at 8:00 PM"
        )
    }

    @Test("Lunch ends at 2:00 PM")
    func lunchAtTwo() {
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "Brandywine",
                period: "Lunch",
                endsAt: twoPM
            ) == "Brandywine, Lunch ends at 2:00 PM"
        )
    }

    @Test("Midnight close formats as 12:00 AM")
    func midnightClose() {
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "Mesa Commons",
                period: "Dinner",
                endsAt: midnight
            ) == "Mesa Commons, Dinner ends at 12:00 AM"
        )
    }

    @Test("Trims hall and period whitespace")
    func trimsWhitespace() {
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "  The Anteatery  ",
                period: " Dinner ",
                endsAt: eightPM
            ) == "The Anteatery, Dinner ends at 8:00 PM"
        )
    }

    @Test("Empty period still announces end time")
    func emptyPeriod() {
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "   ",
                endsAt: eightPM
            ) == "The Anteatery, Ends at 8:00 PM"
        )
    }

    @Test("Wall clock stays Pacific even when device TZ differs")
    func pacificWallClock() {
        // endsAt is fixed UTC; label must use Irvine minutes, not local TZ.
        #expect(UCITime.nowMinutes(now: eightPM) == 20 * 60)
        #expect(
            MealCountdownAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "Dinner",
                endsAt: eightPM
            ).contains("8:00 PM")
        )
    }
}
