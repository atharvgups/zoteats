import Testing
@testable import ZotEatsKit

@Suite("PillSelectionAccessibility")
struct PillSelectionAccessibilityTests {
    @Test("Eat meal pills (no deselect) omit hint — selected trait is enough")
    func noDeselectOmitsHint() {
        #expect(
            PillSelectionAccessibility.hint(
                title: "Lunch",
                isSelected: true,
                allowsDeselect: false
            ) == nil
        )
        #expect(
            PillSelectionAccessibility.hint(
                title: "Dinner",
                isSelected: false,
                allowsDeselect: false
            ) == nil
        )
    }

    @Test("Deselectable selected pill clears")
    func clearsSelection() {
        #expect(
            PillSelectionAccessibility.hint(
                title: "Coffee",
                isSelected: true,
                allowsDeselect: true
            ) == "Clears selection"
        )
    }

    @Test("Deselectable unselected pill selects by name")
    func selectsByName() {
        #expect(
            PillSelectionAccessibility.hint(
                title: "Markets",
                isSelected: false,
                allowsDeselect: true
            ) == "Selects Markets"
        )
    }

    @Test("Blank title yields nil even when deselectable")
    func blankTitle() {
        #expect(
            PillSelectionAccessibility.hint(
                title: "  ",
                isSelected: false,
                allowsDeselect: true
            ) == nil
        )
    }
}
