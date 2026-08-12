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

    @Test("Quietest open tip")
    func quietestOpen() {
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(
                .open(name: "Science Library", percent: 12, facilityID: 2)
            ) == "Quietest: Science Library, 12 percent full"
        )
    }

    @Test("Libraries closed tip includes Study detail")
    func quietestClosed() {
        #expect(
            DiningStatusAccessibilityLabel.quietestTip(.librariesClosed)
                == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }
}
