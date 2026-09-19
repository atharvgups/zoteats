import Foundation

/// Compact Eat Filters chrome for Today's Menu / Favorites widgets.
public enum EatFilterHint {
    /// Short label when any diet or allergen filter is on (nil when clear).
    public static func label(
        dietFilters: [String],
        allergenAvoids: [String]
    ) -> String? {
        let diets = dietFilters.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let avoids = allergenAvoids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !diets.isEmpty || !avoids.isEmpty else { return nil }

        var parts: [String] = []
        parts.append(contentsOf: diets.prefix(2))
        if diets.count > 2 {
            parts.append("+\(diets.count - 2)")
        }
        if !avoids.isEmpty {
            parts.append(avoids.count == 1 ? "−\(avoids[0])" : "−\(avoids.count) allergens")
        }
        return parts.joined(separator: " · ")
    }
}
