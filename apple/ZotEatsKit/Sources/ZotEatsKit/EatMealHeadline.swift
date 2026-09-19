import Foundation

/// Eat tab subtitle — follows the selected meal pill, not just wall-clock hour.
public enum EatMealHeadline: Sendable {
    public static func mealLabel(period: String?) -> String {
        guard let period, !period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return MealPeriodPill.canonical(period)
    }

    /// Classic “What’s for Breakfast / Lunch / Dinner” line.
    public static func subtitle(period: String?, hour: Int = UCITime.hour()) -> String {
        switch mealLabel(period: period) {
        case "Breakfast":
            return "What’s for Breakfast"
        case "Lunch":
            return "What’s for Lunch"
        case "Dinner":
            return "What’s for Dinner"
        default:
            switch hour {
            case ..<12: return "What’s for Breakfast"
            case ..<17: return "What’s for Lunch"
            default: return "What’s for Dinner"
            }
        }
    }
}
