import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDishListLayout")
struct EatDishListLayoutTests {
    @Test func dishesHaveAirBetweenCards() {
        #expect(EatDishListLayout.cardSpacing >= 10)
    }
}
