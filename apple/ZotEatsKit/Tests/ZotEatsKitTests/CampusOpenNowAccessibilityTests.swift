import Testing
@testable import ZotEatsKit

@Suite("CampusOpenNowAccessibility")
struct CampusOpenNowAccessibilityTests {
    @Test("Open-only label and restore hint")
    func openOnly() {
        #expect(CampusOpenNowAccessibility.label(openOnly: true) == "Showing open spots only")
        #expect(CampusOpenNowAccessibility.hint(openOnly: true) == "Shows closed spots again")
    }

    @Test("All-spots label and hide hint")
    func allSpots() {
        #expect(CampusOpenNowAccessibility.label(openOnly: false) == "Showing all spots")
        #expect(CampusOpenNowAccessibility.hint(openOnly: false) == "Hides closed spots")
    }
}
