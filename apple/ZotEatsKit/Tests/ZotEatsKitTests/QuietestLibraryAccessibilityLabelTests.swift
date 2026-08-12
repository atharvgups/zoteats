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
}
