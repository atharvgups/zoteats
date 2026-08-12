import Testing
@testable import ZotEatsKit

@Suite("StudyFacilityAccessibilityLabel")
struct StudyFacilityAccessibilityLabelTests {
    @Test("Open with percent, level, and people of capacity")
    func openFull() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: true,
                percent: 80,
                levelLabel: "Very Busy",
                peopleCount: 480,
                capacity: 600
            ) == "Langson Library, open, 80 percent full, Very Busy, 480 of 600 people"
        )
    }

    @Test("Open with percent, no people")
    func openNoPeople() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Science Library",
                isOpen: true,
                percent: 12,
                levelLabel: "Not Busy",
                peopleCount: nil,
                capacity: nil
            ) == "Science Library, open, 12 percent full, Not Busy"
        )
    }

    @Test("Open without percent keeps level")
    func openLevelOnly() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Gateway Study Center",
                isOpen: true,
                percent: nil,
                levelLabel: "Busy",
                peopleCount: nil,
                capacity: nil
            ) == "Gateway Study Center, open, Busy"
        )
    }

    @Test("Closed announces detail once")
    func closed() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: false,
                percent: nil,
                levelLabel: nil,
                peopleCount: nil,
                capacity: nil
            ) == "Langson Library, closed, Crowding updates when open"
        )
    }

    @Test("Closed prefers Waitz Opens at")
    func closedOpensAt() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: false,
                percent: nil,
                levelLabel: nil,
                peopleCount: nil,
                capacity: nil,
                hoursSummary: "Closed until 8:00am"
            ) == "Langson Library, closed, Opens at 8:00 AM"
        )
    }

    @Test("Closed ignores stale percent level and people")
    func closedIgnoresStale() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: false,
                percent: 40,
                levelLabel: "Not Busy",
                peopleCount: 100,
                capacity: 600
            ) == "Langson Library, closed, Crowding updates when open"
        )
    }

    @Test("Whitespace name falls back to Library")
    func blankName() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "  ",
                isOpen: true,
                percent: 10,
                levelLabel: "Not Busy",
                peopleCount: nil,
                capacity: nil
            ) == "Library, open, 10 percent full, Not Busy"
        )
    }

    @Test("Open appends Updated freshness")
    func openWithUpdated() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: true,
                percent: 80,
                levelLabel: "Very Busy",
                peopleCount: 480,
                capacity: 600,
                updatedRelative: "just now"
            ) == "Langson Library, open, 80 percent full, Very Busy, 480 of 600 people, Updated just now"
        )
    }

    @Test("Closed still announces Updated freshness")
    func closedWithUpdated() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Langson Library",
                isOpen: false,
                percent: 40,
                levelLabel: "Not Busy",
                peopleCount: 100,
                capacity: 600,
                updatedRelative: "2 min. ago"
            ) == "Langson Library, closed, Crowding updates when open, Updated 2 min. ago"
        )
    }

    @Test("Blank updatedRelative is omitted")
    func blankUpdatedOmitted() {
        #expect(
            StudyFacilityAccessibilityLabel.label(
                name: "Science Library",
                isOpen: true,
                percent: 12,
                levelLabel: "Not Busy",
                peopleCount: nil,
                capacity: nil,
                updatedRelative: "  "
            ) == "Science Library, open, 12 percent full, Not Busy"
        )
    }
}
