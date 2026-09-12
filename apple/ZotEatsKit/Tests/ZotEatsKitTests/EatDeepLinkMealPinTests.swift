import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDeepLinkMealPin")
struct EatDeepLinkMealPinTests {
    @Test("Preserved Lunch stays pinned for Opening Alert settle")
    func preservesPinnedLunch() {
        #expect(
            EatDeepLinkMealPin.pin(
                preserveRequestedMeal: true,
                resolvedPeriod: "Lunch"
            ) == "Lunch"
        )
    }

    @Test("Hall-only link does not pin")
    func hallOnlyClearsPin() {
        #expect(
            EatDeepLinkMealPin.pin(
                preserveRequestedMeal: false,
                resolvedPeriod: "Dinner"
            ) == nil
        )
    }

    @Test("Preserve without resolved period clears pin")
    func unresolvedClearsPin() {
        #expect(
            EatDeepLinkMealPin.pin(
                preserveRequestedMeal: true,
                resolvedPeriod: nil
            ) == nil
        )
    }
}
