import Testing
@testable import ZotEatsKit

@Suite("DietFilterRowAccessibility")
struct DietFilterRowAccessibilityTests {
    @Test("Diet row label includes subtitle meaning")
    func dietSubtitle() {
        #expect(
            DietFilterRowAccessibility.label(
                title: "Vegan",
                subtitle: "Only vegan dishes"
            ) == "Vegan filter, Only vegan dishes"
        )
    }

    @Test("Allergen row label includes hide subtitle")
    func allergenSubtitle() {
        #expect(
            DietFilterRowAccessibility.label(
                title: "Eggs",
                subtitle: "Hide dishes with eggs"
            ) == "Eggs filter, Hide dishes with eggs"
        )
    }

    @Test("Selected hint turns filter off")
    func selectedHint() {
        #expect(DietFilterRowAccessibility.hint(isSelected: true) == "Turns this filter off")
    }

    @Test("Unselected hint turns filter on")
    func unselectedHint() {
        #expect(DietFilterRowAccessibility.hint(isSelected: false) == "Turns this filter on")
    }

    @Test("Blank title falls back without empty filter name")
    func blankTitle() {
        #expect(
            DietFilterRowAccessibility.label(title: "  ", subtitle: "Only vegan dishes")
                == "Filter, Only vegan dishes"
        )
    }

    @Test("Blank subtitle omits detail")
    func blankSubtitle() {
        #expect(
            DietFilterRowAccessibility.label(title: "Halal", subtitle: "\n")
                == "Halal filter"
        )
    }
}
