import Foundation

/// Display label for a meal period — prefer the live API name (Brunch,
/// Limited Dinner) for chrome; fall back to the primary Eat pill.
public enum MealPeriodDisplay {
    public static func label(live: String, pill: String = "") -> String {
        let liveTrim = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveTrim.isEmpty { return liveTrim }
        return pill.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
