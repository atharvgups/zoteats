import Testing
@testable import ZotEatsKit

@Suite("DiningHallCardAccessibilityLabel")
struct DiningHallCardAccessibilityLabelTests {
    @Test("Open with closes-in status and occupancy")
    func openClosesIn() {
        #expect(
            DiningHallCardAccessibilityLabel.label(
                name: "Brandywine",
                isOpen: true,
                statusLine: "Lunch · closes in 12m",
                occupancyPercent: 42
            ) == "Brandywine, open, Lunch · closes in 12m, 42 percent occupancy"
        )
    }

    @Test("Closed with tomorrow breakfast")
    func closedTomorrow() {
        #expect(
            DiningHallCardAccessibilityLabel.label(
                name: "The Anteatery",
                isOpen: false,
                statusLine: "Breakfast tomorrow · 7:15 AM",
                occupancyPercent: nil
            ) == "The Anteatery, closed, Breakfast tomorrow · 7:15 AM"
        )
    }

    @Test("Opening later without occupancy")
    func openingLater() {
        #expect(
            DiningHallCardAccessibilityLabel.label(
                name: "Brandywine",
                isOpen: false,
                statusLine: "Dinner at 5:00 PM",
                occupancyPercent: nil
            ) == "Brandywine, closed, Dinner at 5:00 PM"
        )
    }

    @Test("Empty statusLine omits blank part")
    func emptyStatus() {
        #expect(
            DiningHallCardAccessibilityLabel.label(
                name: "Brandywine",
                isOpen: false,
                statusLine: "  ",
                occupancyPercent: nil
            ) == "Brandywine, closed"
        )
    }
}
