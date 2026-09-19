import Foundation
import Testing
@testable import ZotEatsKit

@Suite("PlateQuantity")
struct PlateQuantityTests {
    @Test func incrementAddsAnotherServing() {
        #expect(PlateQuantity.incremented(1) == 2)
        #expect(PlateQuantity.incremented(2) == 3)
        #expect(PlateQuantity.incremented(99) == 99)
    }

    @Test func decrementRemovesTheLastServing() {
        #expect(PlateQuantity.decremented(3) == 2)
        #expect(PlateQuantity.decremented(1) == nil)
    }

    @Test func addCopySwitchesAfterTheFirstServing() {
        #expect(PlateQuantityCopy.addButtonTitle(quantity: 0) == "Add to Plate")
        #expect(PlateQuantityCopy.addButtonTitle(quantity: 1) == "Add another")
        #expect(
            PlateQuantityCopy.addAccessibility(dishName: "Soup", quantity: 0)
                == "Add Soup to my plate"
        )
        #expect(
            PlateQuantityCopy.addAccessibility(dishName: "Soup", quantity: 2)
                == "Add another serving of Soup to my plate"
        )
    }
}

@Suite("PlateTotals quantity")
struct PlateTotalsQuantityTests {
    @Test func twoServingsDoubleTheMacros() {
        let one = PlateEntry(dishName: "Bowl", calories: 420, proteinG: 14, quantity: 1)
        let two = one.updatingQuantity(2)
        #expect(PlateTotals.calories(from: [two]) == 840)
        #expect(PlateTotals.proteinGrams(from: [two]) == 28)
        #expect(PlateTotals.servingCount(from: [two]) == 2)
        #expect(two.lineCalories == 840)
    }

    @Test func mixedQuantitiesSumServings() {
        let entries = [
            PlateEntry(dishName: "Bowl", calories: 420, proteinG: 14, quantity: 2),
            PlateEntry(dishName: "Soup", calories: 180, proteinG: 8, quantity: 1),
        ]
        #expect(PlateTotals.calories(from: entries) == 1020)
        #expect(PlateTotals.servingCount(from: entries) == 3)
    }

    @Test func oldSavesWithoutQuantityDecodeAsOne() throws {
        let id = UUID()
        let data = """
        {"id":"\(id.uuidString)","dishName":"Bowl","calories":420,"proteinG":14}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(PlateEntry.self, from: data)
        #expect(entry.quantity == 1)
        #expect(entry.lineCalories == 420)
    }
}
