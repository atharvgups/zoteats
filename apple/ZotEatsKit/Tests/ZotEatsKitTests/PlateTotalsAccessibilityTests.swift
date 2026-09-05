import Testing
@testable import ZotEatsKit

@Suite("PlateTotalsAccessibility")
struct PlateTotalsAccessibilityTests {
    @Test("Empty plate hides totals from VoiceOver")
    func emptyHides() {
        #expect(!PlateTotalsAccessibility.shouldAnnounceTotals(isEmpty: true))
    }

    @Test("Non-empty plate announces totals")
    func nonEmptyAnnounces() {
        #expect(PlateTotalsAccessibility.shouldAnnounceTotals(isEmpty: false))
    }

    @Test("Calories label formatting")
    func caloriesLabel() {
        #expect(
            PlateTotalsAccessibility.label(name: "Calories", value: "420")
                == "Calories: 420"
        )
    }

    @Test("Protein label formatting")
    func proteinLabel() {
        #expect(
            PlateTotalsAccessibility.label(name: "Protein", value: "23g")
                == "Protein: 23g"
        )
    }

    @Test("Blank name falls back to Total")
    func blankName() {
        #expect(
            PlateTotalsAccessibility.label(name: "  ", value: "10")
                == "Total: 10"
        )
    }

    @Test("Blank value keeps heading only")
    func blankValue() {
        #expect(
            PlateTotalsAccessibility.label(name: "Calories", value: "\n")
                == "Calories"
        )
    }
}
