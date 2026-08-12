import Testing
@testable import ZotEatsKit

@Suite("PlateEntryAccessibility")
struct PlateEntryAccessibilityTests {
    @Test("Name plus calories expands cal abbreviation")
    func withCalories() {
        #expect(
            PlateEntryAccessibility.label(dishName: "Chicken Teriyaki", calories: 420)
                == "Chicken Teriyaki, 420 calories"
        )
    }

    @Test("Nil calories is dish name only")
    func noCalories() {
        #expect(
            PlateEntryAccessibility.label(dishName: "Chicken Teriyaki", calories: nil)
                == "Chicken Teriyaki"
        )
    }

    @Test("Blank name with calories falls back to Dish")
    func blankNameWithCalories() {
        #expect(
            PlateEntryAccessibility.label(dishName: "  ", calories: 420)
                == "Dish, 420 calories"
        )
    }

    @Test("Blank name without calories is Dish")
    func blankNameOnly() {
        #expect(
            PlateEntryAccessibility.label(dishName: "\n", calories: nil)
                == "Dish"
        )
    }

    @Test("Trims dish name whitespace")
    func trimsName() {
        #expect(
            PlateEntryAccessibility.label(dishName: "  Soup  ", calories: 180)
                == "Soup, 180 calories"
        )
    }
}
