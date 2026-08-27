import Foundation

/// Map live API meal names (Brunch, Limited Dinner, …) onto Eat primary pills
/// (Breakfast / Lunch / Dinner) for deep links and sticky selection.
public enum MealPeriodPill {
    /// Canonical pill label for a live or already-primary period name.
    public static func canonical(_ liveName: String) -> String {
        let trimmed = liveName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.contains("brunch") || lower.contains("breakfast") { return "Breakfast" }
        if lower.contains("lunch") { return "Lunch" }
        if lower.contains("dinner") { return "Dinner" }
        return trimmed
    }

    /// Prefer a pill present in `pills` that matches the live name.
    public static func match(_ liveName: String, in pills: [String]) -> String? {
        guard !pills.isEmpty else { return nil }
        let canonical = Self.canonical(liveName)
        if let match = pills.first(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) {
            return match
        }
        if let exact = pills.first(where: { $0.caseInsensitiveCompare(liveName) == .orderedSame }) {
            return exact
        }
        return pills.first
    }
}
