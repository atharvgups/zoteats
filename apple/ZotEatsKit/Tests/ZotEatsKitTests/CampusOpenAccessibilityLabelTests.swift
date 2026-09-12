import Testing
@testable import ZotEatsKit

@Suite("CampusOpenAccessibilityLabel")
struct CampusOpenAccessibilityLabelTests {
    @Test("Empty with next-open announces the hint")
    func emptyWithHint() {
        #expect(
            CampusOpenAccessibilityLabel.label(
                totalOpen: 0,
                openPlaceNames: [],
                nextOpenLine: "Starbucks opens at 7:30 AM"
            ) == "Nothing's open right now. Starbucks opens at 7:30 AM"
        )
    }

    @Test("Empty without hint stays honest")
    func emptyNoHint() {
        #expect(
            CampusOpenAccessibilityLabel.label(
                totalOpen: 0,
                openPlaceNames: [],
                nextOpenLine: nil
            ) == "Nothing's open right now."
        )
        #expect(
            !CampusOpenAccessibilityLabel.label(
                totalOpen: 0,
                openPlaceNames: [],
                nextOpenLine: nil
            ).contains("0 campus")
        )
    }

    @Test("Open lists count and place names")
    func openListsPlaces() {
        #expect(
            CampusOpenAccessibilityLabel.label(
                totalOpen: 5,
                openPlaceNames: ["Starbucks", "Panda Express", "Subway", "Zot N Go"],
                nextOpenLine: nil
            ) == "5 campus spots open. Starbucks, Panda Express, Subway. and 2 more"
        )
    }

    @Test("Single open spot singular")
    func singular() {
        #expect(
            CampusOpenAccessibilityLabel.label(
                totalOpen: 1,
                openPlaceNames: ["Starbucks @ Student Center"],
                nextOpenLine: nil
            ) == "1 campus spot open. Starbucks @ Student Center"
        )
    }
}
