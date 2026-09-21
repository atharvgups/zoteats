import Testing
@testable import ZotEatsKit

@Suite("TwistedRootBoardCopy")
struct TwistedRootBoardCopyTests {
    @Test func silentWhenCurrentPillPostedTheStation() {
        #expect(
            TwistedRootBoardCopy.message(
                currentMeal: "Lunch", postedMeals: ["Lunch", "Dinner"]
            ) == nil
        )
        #expect(
            TwistedRootBoardCopy.actionTitle(
                currentMeal: "Lunch", postedMeals: ["Lunch", "Dinner"]
            ) == "See Dinner"
        )
    }

    @Test func namesOtherMealsWithoutInventingDishes() {
        #expect(
            TwistedRootBoardCopy.message(
                currentMeal: "Breakfast", postedMeals: ["Lunch", "Dinner"]
            ) == "Twisted Root isn’t posted for Breakfast. It’s on Lunch and Dinner today."
        )
        #expect(
            TwistedRootBoardCopy.actionTitle(
                currentMeal: "Breakfast", postedMeals: ["Lunch", "Dinner"]
            ) == "See Lunch"
        )
        #expect(
            TwistedRootBoardCopy.message(
                currentMeal: "Breakfast", postedMeals: ["Dinner"]
            ) == "Twisted Root isn’t posted for Breakfast. It’s on Dinner today."
        )
    }

    @Test func notPostedTodayWhenSourceHasNoStation() {
        #expect(
            TwistedRootBoardCopy.message(currentMeal: "Breakfast", postedMeals: [])
                == "Twisted Root isn’t posted today."
        )
        #expect(
            TwistedRootBoardCopy.actionTitle(currentMeal: "Breakfast", postedMeals: []) == nil
        )
    }
}
