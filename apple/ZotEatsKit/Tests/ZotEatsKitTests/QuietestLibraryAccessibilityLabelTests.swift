import Testing
@testable import ZotEatsKit

@Suite("QuietestLibraryAccessibilityLabel")
struct QuietestLibraryAccessibilityLabelTests {
    @Test("Closed includes overnight detail (circular parity)")
    func closed() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: QuietestLibraryGlance.closedTitle,
                percent: nil
            ) == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }

    @Test("Closed ignores quietest qualifier")
    func closedIgnoresQualifier() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: QuietestLibraryGlance.closedTitle,
                percent: nil,
                includeQuietestQualifier: true
            ) == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }

    @Test("Open announces percent full")
    func open() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: "Langson · 4th Floor",
                percent: 8
            ) == "Langson · 4th Floor, 8 percent full"
        )
    }

    @Test("Rectangular open adds quietest qualifier")
    func openWithQualifier() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: "Langson · 4th Floor",
                percent: 8,
                includeQuietestQualifier: true
            ) == "Langson · 4th Floor, 8 percent full, quietest library right now"
        )
    }

    @Test("Empty closed name falls back to closedTitle")
    func emptyClosedName() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(name: "  ", percent: nil)
                == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }

    @Test("Open appends Updated freshness")
    func openUpdated() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: "Langson · 4th Floor",
                percent: 8,
                updatedRelative: "just now"
            ) == "Langson · 4th Floor, 8 percent full, Updated just now"
        )
    }

    @Test("Rectangular qualifier then Updated")
    func qualifierThenUpdated() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: "Langson · 4th Floor",
                percent: 8,
                includeQuietestQualifier: true,
                updatedRelative: "5 min. ago"
            ) == "Langson · 4th Floor, 8 percent full, quietest library right now, Updated 5 min. ago"
        )
    }

    @Test("Blank updatedRelative is omitted")
    func blankUpdatedOmitted() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: "Langson · 4th Floor",
                percent: 8,
                updatedRelative: "  "
            ) == "Langson · 4th Floor, 8 percent full"
        )
    }

    @Test("Closed ignores Updated relative")
    func closedIgnoresUpdated() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: QuietestLibraryGlance.closedTitle,
                percent: nil,
                updatedRelative: "just now"
            ) == "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        )
    }

    @Test("Closed prefers Waitz Opens at")
    func closedOpensAt() {
        #expect(
            QuietestLibraryAccessibilityLabel.label(
                name: QuietestLibraryGlance.closedTitle,
                percent: nil,
                reopenMinutes: 8 * 60,
                nowMinutes: 6 * 60
            ) == "\(QuietestLibraryGlance.closedTitle). Opens at 8:00 AM"
        )
    }
}
