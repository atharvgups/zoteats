import Testing
@testable import ZotEatsKit

@Suite("MenuFiltersChipAccessibility")
struct MenuFiltersChipAccessibilityTests {
    @Test("Idle title and VoiceOver")
    func idle() {
        #expect(
            MenuFiltersChipAccessibility.title(dietFilters: [], allergenAvoids: [])
                == "Filters"
        )
        #expect(
            MenuFiltersChipAccessibility.accessibilityLabel(dietFilters: [], allergenAvoids: [])
                == "Menu filters"
        )
    }

    @Test("Single diet keeps the name in title and VO")
    func singleDiet() {
        #expect(
            MenuFiltersChipAccessibility.title(dietFilters: ["Vegan"], allergenAvoids: [])
                == "Vegan"
        )
        #expect(
            MenuFiltersChipAccessibility.accessibilityLabel(dietFilters: ["Vegan"], allergenAvoids: [])
                == "Menu filters: Vegan"
        )
    }

    @Test("Single allergen uses No prefix")
    func singleAllergen() {
        #expect(
            MenuFiltersChipAccessibility.title(dietFilters: [], allergenAvoids: ["Peanuts"])
                == "No Peanuts"
        )
        #expect(
            MenuFiltersChipAccessibility.accessibilityLabel(dietFilters: [], allergenAvoids: ["Peanuts"])
                == "Menu filters: No Peanuts"
        )
    }

    @Test("Multi uses N filters (Eat shape, not Filters · N)")
    func multi() {
        #expect(
            MenuFiltersChipAccessibility.title(
                dietFilters: ["Vegan", "Halal"],
                allergenAvoids: ["Soy"]
            ) == "3 filters"
        )
        #expect(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: ["Vegan", "Halal"],
                allergenAvoids: ["Soy"]
            ) == "Menu filters: 3 filters"
        )
    }

    @Test("Blank strings are ignored")
    func ignoresBlanks() {
        #expect(
            MenuFiltersChipAccessibility.title(
                dietFilters: ["  ", "Vegan"],
                allergenAvoids: ["\n"]
            ) == "Vegan"
        )
        #expect(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: ["  "],
                allergenAvoids: []
            ) == "Menu filters"
        )
    }
}
