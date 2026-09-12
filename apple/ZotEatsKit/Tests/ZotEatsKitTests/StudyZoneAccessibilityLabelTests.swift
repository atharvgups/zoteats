import Testing
@testable import ZotEatsKit

@Suite("StudyZoneAccessibilityLabel")
struct StudyZoneAccessibilityLabelTests {
    @Test("Percent plus level matches colored bar meaning")
    func percentAndLevel() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "2nd Floor - Open Seating",
                percent: 26,
                levelLabel: "Not busy"
            ) == "2nd Floor - Open Seating, 26 percent full, Not busy"
        )
    }

    @Test("Blank level is omitted")
    func blankLevel() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "Basement",
                percent: 40,
                levelLabel: "  "
            ) == "Basement, 40 percent full"
        )
    }

    @Test("Nil percent is no occupancy data (ignores No data level)")
    func noPercent() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "Basement",
                percent: nil,
                levelLabel: "No data"
            ) == "Basement, no occupancy data"
        )
    }

    @Test("No data level skipped when percent is present")
    func skipsNoDataWithPercent() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "Lobby",
                percent: 5,
                levelLabel: "No data"
            ) == "Lobby, 5 percent full"
        )
    }

    @Test("Blank name falls back to Zone")
    func blankName() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "\n",
                percent: 10,
                levelLabel: "Busy"
            ) == "Zone, 10 percent full, Busy"
        )
    }

    @Test("Trims name and level whitespace")
    func trims() {
        #expect(
            StudyZoneAccessibilityLabel.label(
                fullName: "  Quiet Room  ",
                percent: 8,
                levelLabel: " Very busy "
            ) == "Quiet Room, 8 percent full, Very busy"
        )
    }
}
