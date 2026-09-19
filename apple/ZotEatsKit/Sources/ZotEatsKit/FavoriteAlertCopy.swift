import Foundation

/// Notification body for Favorite Alerts — don't say "Being served" for a meal
/// that hasn't opened yet (morning BG checks include upcoming Lunch/Dinner).
public enum FavoriteAlertCopy {
    public static func body(
        hallName: String,
        period: String,
        servingNow: Bool
    ) -> String {
        let meal = MealPeriodDisplay.label(live: period).lowercased()
        if servingNow {
            return "Being served now at \(hallName) for \(meal)."
        }
        return "On today's \(meal) menu at \(hallName)."
    }
}
