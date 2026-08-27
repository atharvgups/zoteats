import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealPeriodDisplay")
struct MealPeriodDisplayTests {
    @Test func prefersLiveName() {
        #expect(MealPeriodDisplay.label(live: "Brunch", pill: "Breakfast") == "Brunch")
        #expect(MealPeriodDisplay.label(live: "Limited Dinner", pill: "Dinner") == "Limited Dinner")
    }

    @Test func fallsBackToPillWhenLiveEmpty() {
        #expect(MealPeriodDisplay.label(live: "  ", pill: "Lunch") == "Lunch")
        #expect(MealPeriodDisplay.label(live: "", pill: "Dinner") == "Dinner")
    }
}
