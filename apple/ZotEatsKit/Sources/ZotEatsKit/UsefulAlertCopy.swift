import Foundation

/// Lean notification copy — meal start / closing soon, campus hours, library busy.
public enum UsefulAlertCopy {
    public static func closingSoonTitle(placeName: String, mealPeriod: String?) -> String {
        let meal = mealPeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !meal.isEmpty {
            return "\(placeName) · \(MealPeriodDisplay.label(live: meal)) closing soon"
        }
        return "\(placeName) closing soon"
    }

    public static func closingSoonBody(closesAtMinutes: Int) -> String {
        "Closes at \(UCITime.format(minutes: closesAtMinutes % (24 * 60))). Head over if you still need it."
    }

    public static func libraryBusyTitle(name: String) -> String {
        "\(name) is getting busy"
    }

    public static func libraryBusyBody(percent: Int) -> String {
        "Live Waitz reading: \(percent)%. Open Study to pick a quieter floor."
    }
}
