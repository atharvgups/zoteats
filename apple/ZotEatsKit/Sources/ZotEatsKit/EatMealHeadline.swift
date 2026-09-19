import Foundation

/// Eat tab subtitle — follows the selected meal pill, not just wall-clock hour.
public enum EatMealHeadline: Sendable {
    public static func mealLabel(period: String?) -> String {
        guard let period, !period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return MealPeriodPill.canonical(period)
    }

    /// Simple static line when Apple Intelligence / Foundation Models are off.
    public static func subtitle(period: String?, hour: Int = UCITime.hour()) -> String {
        switch mealLabel(period: period) {
        case "Breakfast":
            return hour < 5 ? "Still hungry, Anteater?" : "What’s for breakfast?"
        case "Lunch":
            return "What’s for lunch?"
        case "Dinner":
            return hour >= 21 ? "Dinner plans, Anteater?" : "What’s for dinner?"
        default:
            switch hour {
            case ..<4: return "Still hungry, Anteater?"
            case ..<12: return "What’s for breakfast?"
            case ..<17: return "What’s for lunch?"
            default: return "What’s for dinner?"
            }
        }
    }

    /// One-line cap so a Foundation Models easter egg never wraps the header.
    public static func sanitizeGenerated(_ raw: String, fallback: String) -> String {
        var line = raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while line.contains("  ") {
            line = line.replacingOccurrences(of: "  ", with: " ")
        }
        guard !line.isEmpty, line.count <= 48, line != fallback else { return fallback }
        return line
    }
}
