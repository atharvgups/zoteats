import Foundation
import Testing
@testable import ZotEatsKit

@Suite("PlateTotals")
struct PlateTotalsTests {
    @Test func sumsCaloriesAndRoundsProtein() {
        let entries = [
            PlateEntry(dishName: "Bowl", calories: 420, proteinG: 14.2),
            PlateEntry(dishName: "Soup", calories: 180, proteinG: 8.6),
            PlateEntry(dishName: "No macros", calories: nil, proteinG: nil),
        ]
        #expect(PlateTotals.calories(from: entries) == 600)
        // 14.2 + 8.6 = 22.8 → rounds to 23
        #expect(PlateTotals.proteinGrams(from: entries) == 23)
    }

    @Test func emptyPlateIsZero() {
        #expect(PlateTotals.calories(from: []) == 0)
        #expect(PlateTotals.proteinGrams(from: []) == 0)
    }

    @Test func nutritionFactsHasMacrosAndDetails() {
        let empty = NutritionFacts()
        #expect(!empty.hasMacros)
        #expect(!empty.hasDetails)

        let macrosOnly = NutritionFacts(proteinG: 10, totalCarbsG: 20, totalFatG: 5)
        #expect(macrosOnly.hasMacros)
        #expect(macrosOnly.hasDetails)

        let ingredientsOnly = NutritionFacts(ingredients: "Water, salt")
        #expect(!ingredientsOnly.hasMacros)
        #expect(ingredientsOnly.hasDetails)
    }
}
