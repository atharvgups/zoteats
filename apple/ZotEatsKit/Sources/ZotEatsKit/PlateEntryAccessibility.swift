import Foundation

/// VoiceOver for a My Plate dish row — one label for name + macros so VO
/// doesn't stall on abbreviated "cal"; Remove stays a separate control.
public enum PlateEntryAccessibility {
    public static func label(dishName: String, calories: Int?, proteinG: Int? = nil) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = name.isEmpty ? "Dish" : name
        var parts: [String] = [heading]
        if let calories {
            parts.append("\(calories) calories")
        }
        if let proteinG {
            parts.append("\(proteinG) grams protein")
        }
        return parts.joined(separator: ", ")
    }
}
