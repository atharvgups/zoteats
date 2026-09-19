import Foundation

/// My Plate row remove chrome — a labeled control, not a faint minus glyph.
public enum PlateRemoveCopy {
    public static let button = "Remove"

    public static func accessibilityLabel(dishName: String) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let dish = name.isEmpty ? "dish" : name
        return "Remove \(dish) from plate"
    }
}
