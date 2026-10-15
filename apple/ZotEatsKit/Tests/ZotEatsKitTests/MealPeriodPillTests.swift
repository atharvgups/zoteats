import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealPeriodPill")
struct MealPeriodPillTests {
    @Test func canonicalMapsBrunchAndLimitedDinner() {
        #expect(MealPeriodPill.canonical("Brunch") == "Breakfast")
        #expect(MealPeriodPill.canonical("Limited Dinner") == "Dinner")
        #expect(MealPeriodPill.canonical("Lunch") == "Lunch")
        #expect(MealPeriodPill.canonical("  Dinner  ") == "Dinner")
        #expect(MealPeriodPill.canonical("Afternoon Snack") == "Afternoon Snack")
        #expect(MealPeriodPill.canonical("Evening Snack") == "Late Night")
        #expect(MealPeriodPill.canonical("Overnight") == "Late Night")
        #expect(MealPeriodPill.canonical("Late Night") == "Late Night")
    }

    @Test func matchPrefersPrimaryInPills() {
        let pills = ["Breakfast", "Dinner"]
        #expect(MealPeriodPill.match("Brunch", in: pills) == "Breakfast")
        #expect(MealPeriodPill.match("Limited Dinner", in: pills) == "Dinner")
        #expect(MealPeriodPill.match("Breakfast", in: pills) == "Breakfast")
    }

    @Test func matchEmptyPillsReturnsNil() {
        #expect(MealPeriodPill.match("Brunch", in: []) == nil)
    }
}
