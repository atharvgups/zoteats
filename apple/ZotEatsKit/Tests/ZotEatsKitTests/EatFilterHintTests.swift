import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatFilterHint")
struct EatFilterHintTests {
    @Test func nilWhenClear() {
        #expect(EatFilterHint.label(dietFilters: [], allergenAvoids: []) == nil)
    }

    @Test func dietsAndAvoids() {
        let label = EatFilterHint.label(
            dietFilters: ["Vegan", "Vegetarian", "Halal"],
            allergenAvoids: ["Peanuts"]
        )
        #expect(label == "Vegan · Vegetarian · +1 · −Peanuts")
    }
}
