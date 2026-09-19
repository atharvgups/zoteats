import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusCategoryEmptyCopy")
struct CampusCategoryEmptyCopyTests {
    private func place(
        id: String,
        name: String,
        category: String,
        opensAt: Int? = nil,
        opensTomorrow: Int? = nil
    ) -> CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            category: category,
            openNow: false,
            todayHours: nil,
            opensAtMinutes: opensAt,
            opensTomorrowAtMinutes: opensTomorrow
        )
    }

    @Test func scopesPlacesToTypeFilter() {
        let all = [
            place(id: "sb", name: "Starbucks", category: "Coffee & Cafés", opensAt: 7 * 60 + 30),
            place(id: "px", name: "Panda", category: "Food Courts", opensAt: 10 * 60),
            place(id: "pub", name: "Anthill Pub", category: "Restaurants & Pubs", opensAt: 11 * 60),
        ]
        let coffee = CampusCategoryEmptyCopy.places(matching: .coffee, from: all)
        #expect(coffee.map(\.id) == ["sb"])
        let food = CampusCategoryEmptyCopy.places(matching: .food, from: all)
        #expect(Set(food.map(\.id)) == Set(["px", "pub"]))
        let hint = CampusNextOpenHint.best(from: coffee)
        #expect(hint?.placeID == "sb")
    }

    @Test func legacyCategoryScopeStillWorks() {
        let all = [
            place(id: "sb", name: "Starbucks", category: "Coffee & Cafés", opensAt: 7 * 60 + 30),
            place(id: "px", name: "Panda", category: "Food Courts", opensAt: 10 * 60),
        ]
        let coffee = CampusCategoryEmptyCopy.places(inCategory: "Coffee & Cafés", from: all)
        #expect(coffee.map(\.id) == ["sb"])
    }

    @Test func openOnlyMessageIncludesHint() {
        let hint = CampusNextOpenHint.Hint(
            placeID: "sb",
            placeName: "Starbucks @ Student Center",
            opensAtMinutes: 7 * 60 + 30,
            isTomorrow: false
        )
        let message = CampusCategoryEmptyCopy.message(openOnly: true, hint: hint)
        #expect(message.contains("Starbucks opens at 7:30 AM"))
        #expect(message.contains("Open it for hours or menu"))
        #expect(message.localizedCaseInsensitiveContains("clear the filter"))
    }

    @Test func viewNextActionTitleUsesShortName() {
        #expect(
            CampusCategoryEmptyCopy.viewNextActionTitle(shortName: "Starbucks")
                == "View Starbucks"
        )
        #expect(
            CampusCategoryEmptyCopy.viewNextActionTitle(shortName: "  ")
                == "View spot"
        )
    }

    @Test func openOnlyWithoutHintKeepsGeneric() {
        #expect(
            CampusCategoryEmptyCopy.message(openOnly: true, hint: nil)
                == "Try clearing the type filter, or show closed spots from the chip."
        )
    }

    @Test func filterWithoutOpenOnlyIgnoresHint() {
        let hint = CampusNextOpenHint.Hint(
            placeID: "sb",
            placeName: "Starbucks",
            opensAtMinutes: 7 * 60 + 30,
            isTomorrow: true
        )
        #expect(
            CampusCategoryEmptyCopy.message(openOnly: false, hint: hint)
                == "Clear the type filter to see other campus spots."
        )
    }
}
