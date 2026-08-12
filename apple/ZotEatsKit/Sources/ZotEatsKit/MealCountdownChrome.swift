import Foundation

/// Lock-screen / Island copy for the meal-end Live Activity.
public enum MealCountdownChrome {
    public static func hasEnded(endsAt: Date, now: Date = Date()) -> Bool {
        now >= endsAt
    }

    /// Lock-screen secondary line under the hall name.
    public static func lockStatus(period: String, hasEnded: Bool) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if meal.isEmpty {
            return hasEnded ? "Meal has ended" : "Ends in"
        }
        return hasEnded ? "\(meal) has ended" : "\(meal) ends in"
    }

    /// Expanded Island bottom line.
    public static func islandBottom(period: String, hasEnded: Bool) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasEnded {
            if meal.isEmpty { return "This meal has ended — see what's next" }
            return "\(meal) has ended — see what's next"
        }
        if meal.isEmpty {
            return "Wrapping up — grab a bite while you can"
        }
        return "\(meal) is wrapping up — grab a bite while you can"
    }
}
