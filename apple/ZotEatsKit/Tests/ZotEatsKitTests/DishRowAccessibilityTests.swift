import Testing
@testable import ZotEatsKit

@Suite("DishRowAccessibility")
struct DishRowAccessibilityTests {
    @Test("Full combo: name, calories, diet, Contains allergen")
    func fullCombo() {
        #expect(
            DishRowAccessibility.label(
                dishName: "Tofu Bowl",
                calories: 420,
                dietaryTags: ["Vegan"],
                allergens: ["Soy"]
            ) == "Tofu Bowl, 420 calories, Vegan, Contains Soy"
        )
    }

    @Test("Name and calories only")
    func nameAndCalories() {
        #expect(
            DishRowAccessibility.label(
                dishName: "Chicken Teriyaki",
                calories: 520,
                dietaryTags: [],
                allergens: []
            ) == "Chicken Teriyaki, 520 calories"
        )
    }

    @Test("Name and tags without calories")
    func nameAndTags() {
        #expect(
            DishRowAccessibility.label(
                dishName: "Salad",
                calories: nil,
                dietaryTags: ["Vegetarian", "Halal"],
                allergens: []
            ) == "Salad, Vegetarian, Halal"
        )
    }

    @Test("Allergens use Contains prefix")
    func allergensContain() {
        #expect(
            DishRowAccessibility.label(
                dishName: "Pasta",
                calories: nil,
                dietaryTags: [],
                allergens: ["Wheat", "Milk"]
            ) == "Pasta, Contains Wheat, Contains Milk"
        )
    }

    @Test("Blank name falls back to Dish")
    func blankName() {
        #expect(
            DishRowAccessibility.label(
                dishName: "  ",
                calories: 100,
                dietaryTags: [],
                allergens: []
            ) == "Dish, 100 calories"
        )
    }

    @Test("Trims name and drops empty tag strings")
    func trimsAndDropsEmpties() {
        #expect(
            DishRowAccessibility.label(
                dishName: "  Soup  ",
                calories: 180,
                dietaryTags: ["", "  ", "Vegan"],
                allergens: ["\n", "Sesame"]
            ) == "Soup, 180 calories, Vegan, Contains Sesame"
        )
    }

    @Test("Rated dish announces stars")
    func includesStars() {
        #expect(
            DishRowAccessibility.label(
                dishName: "Tofu Bowl",
                calories: 420,
                dietaryTags: [],
                allergens: [],
                stars: 4
            ) == "Tofu Bowl, 420 calories, 4 stars"
        )
    }
}
