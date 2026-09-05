import Testing
@testable import ZotEatsKit

@Suite("CampusPlaceAccessibilityLabel")
struct CampusPlaceAccessibilityLabelTests {
    @Test("Nested closed includes Opens at hours")
    func nestedClosedOpensAt() {
        #expect(
            CampusPlaceAccessibilityLabel.nested(
                brand: "Starbucks",
                locationDetail: "Student Center",
                openNow: false,
                hoursLine: "Opens at 7:30 AM"
            ) == "Starbucks at Student Center, closed, Opens at 7:30 AM"
        )
    }

    @Test("Nested open includes Open until hours")
    func nestedOpenUntil() {
        #expect(
            CampusPlaceAccessibilityLabel.nested(
                brand: "Starbucks",
                locationDetail: "Student Center",
                openNow: true,
                hoursLine: "Open until 4:00 PM"
            ) == "Starbucks at Student Center, open, Open until 4:00 PM"
        )
    }

    @Test("Nested falls back to brand when detail missing")
    func nestedNoDetail() {
        #expect(
            CampusPlaceAccessibilityLabel.nested(
                brand: "Starbucks",
                locationDetail: nil,
                openNow: false,
                hoursLine: "Opens tomorrow at 8:00 AM"
            ) == "Starbucks, closed, Opens tomorrow at 8:00 AM"
        )
    }

    @Test("Empty hoursLine has no trailing empty part")
    func emptyHours() {
        #expect(
            CampusPlaceAccessibilityLabel.nested(
                brand: "Starbucks",
                locationDetail: "Aldrich Hall",
                openNow: false,
                hoursLine: "  "
            ) == "Starbucks at Aldrich Hall, closed"
        )
    }

    @Test("Flat place includes menu when available")
    func flatWithMenu() {
        #expect(
            CampusPlaceAccessibilityLabel.place(
                name: "Zot N Go",
                openNow: true,
                hoursLine: "Open until 8:00 PM",
                hasMenu: true
            ) == "Zot N Go, open, Open until 8:00 PM, menu available"
        )
    }
}
