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

    @Test func allDayAndBrunchNeverBecomeSelectorPills() {
        #expect(MealPeriodPill.canonical("Brunch") == "Breakfast")
        #expect(MealPeriodPill.selectorPills(from: ["Brunch", "All Day", "Lite Lunch"])
            == ["Breakfast", "Lunch", "Dinner"])
        #expect(!MealPeriodPill.selectorPills().contains("Brunch"))
        #expect(!MealPeriodPill.selectorPills().contains("All Day"))
    }
}
