import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusAccessibilityLabel")
struct DiningStatusAccessibilityLabelTests {
    @Test("Open hall announces open, occupancy, closes")
    func openHall() {
        #expect(
            DiningStatusAccessibilityLabel.hall(
                name: "The Anteatery",
                statusText: "Dinner",
                isOpen: true,
                occupancy: 72,
                countdown: .closes
            ) == "The Anteatery, open, Dinner, 72 percent occupancy, closes"
        )
    }

    @Test("Closed hall announces closed and opens — not just the meal name")
    func closedHall() {
        #expect(
            DiningStatusAccessibilityLabel.hall(
                name: "Brandywine",
                statusText: "Dinner",
                isOpen: false,
                occupancy: nil,
                countdown: .opens
            ) == "Brandywine, closed, Dinner, opens"
        )
    }

    @Test("After-hours closed without countdown")
    func closedForToday() {
        #expect(
            DiningStatusAccessibilityLabel.hall(
                name: "Brandywine",
                statusText: "Closed for today",
                isOpen: false,
                occupancy: nil,
                countdown: nil
            ) == "Brandywine, closed, Closed for today"
        )
    }

    @Test("Quietest open tip includes Updated freshness")
    func quietestOpen() {
        let now = Date()
        let tip = QuietestLibraryGlance.DiningStatusTip.open(
            name: "Science Library",
            percent: 12,
            facilityID: 2,
            updatedAt: now.addingTimeInterval(-30)
        )
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(tip, now: now)
                == "Quietest: Science Library, 12 percent full, Updated just now"
        )
    }

    @Test("Quietest open tip minutes ago")
    func quietestOpenMinutesAgo() {
        let now = Date()
        let tip = QuietestLibraryGlance.DiningStatusTip.open(
            name: "Langson · 4th Floor",
            percent: 8,
            facilityID: 3,
            updatedAt: now.addingTimeInterval(-5 * 60)
        )
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(tip, now: now)
                == "Quietest: Langson · 4th Floor, 8 percent full, Updated 5 min. ago"
        )
    }

    @Test("Libraries closed tip includes Study detail")
    func quietestClosed() {
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(.librariesClosed(reopenMinutes: nil))
                == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }

    @Test("Libraries closed tip prefers Waitz Opens at")
    func quietestClosedOpensAt() {
        // Fixed Irvine morning so Closed-until 8 AM stays “Opens at”, not tomorrow.
        let morning = ISO8601DateFormatter().date(from: "2026-07-13T13:00:00Z")! // Mon 6 AM PDT
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(
                .librariesClosed(reopenMinutes: 8 * 60),
                now: morning
            ) == "\(QuietestLibraryGlance.closedTitle). Opens at 8:00 AM"
        )
    }
}
