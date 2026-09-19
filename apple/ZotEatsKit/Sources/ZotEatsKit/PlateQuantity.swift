import Foundation

/// How many servings of one dish sit on today's plate.
public enum PlateQuantity: Sendable {
    public static let minimum = 1
    public static let maximum = 99

    public static func clamped(_ value: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    /// Next count after tapping + on a dish already on the plate.
    public static func incremented(_ current: Int) -> Int {
        clamped(current + 1)
    }

    /// Nil means the dish should leave the plate.
    public static func decremented(_ current: Int) -> Int? {
        current <= minimum ? nil : current - 1
    }
}

/// Add-to-plate chrome when + increments quantity instead of toggling off.
public enum PlateQuantityCopy {
    public static func addButtonTitle(quantity: Int) -> String {
        quantity > 0 ? "Add another" : "Add to Plate"
    }

    public static func addAccessibility(dishName: String, quantity: Int) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let dish = name.isEmpty ? "dish" : name
        return quantity > 0
            ? "Add another serving of \(dish) to my plate"
            : "Add \(dish) to my plate"
    }

    public static func stepperAccessibility(dishName: String, quantity: Int) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let dish = name.isEmpty ? "dish" : name
        let servings = quantity == 1 ? "1 serving" : "\(quantity) servings"
        return "\(dish), \(servings)"
    }
}
