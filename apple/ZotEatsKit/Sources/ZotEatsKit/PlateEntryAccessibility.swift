import Foundation

/// VoiceOver for a My Plate dish row — one label for name + calories so VO
/// doesn't stall on abbreviated "cal"; Remove stays a separate control.
public enum PlateEntryAccessibility {
    public static func label(dishName: String, calories: Int?) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = name.isEmpty ? "Dish" : name
        guard let calories else { return heading }
        return "\(heading), \(calories) calories"
    }
}
