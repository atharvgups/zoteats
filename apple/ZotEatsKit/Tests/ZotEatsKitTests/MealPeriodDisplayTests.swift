import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealPeriodDisplay")
struct MealPeriodDisplayTests {
    @Test func prefersLiveName() {
        #expect(MealPeriodDisplay.label(live: "Brunch", pill: "Breakfast") == "Brunch")
        #expect(MealPeriodDisplay.label(live: "Limited Dinner", pill: "Dinner") == "Limited Dinner")
        #expect(MealPeriodDisplay.label(live: "Overnight", pill: "Late Night") == "Late Night")
        #expect(MealPeriodDisplay.label(live: "Evening Snack", pill: "Late Night") == "Late Night")
        #expect(MealPeriodDisplay.label(live: "Late Night") == "Late Night")
    }

    @Test func fallsBackToPillWhenLiveEmpty() {
        #expect(MealPeriodDisplay.label(live: "  ", pill: "Lunch") == "Lunch")
        #expect(MealPeriodDisplay.label(live: "", pill: "Dinner") == "Dinner")
    }
}
