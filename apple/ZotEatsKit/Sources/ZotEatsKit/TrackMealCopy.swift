import Foundation

/// Eat “Track meal” chip — Atharv: say it logs this meal on My Plate.
public enum TrackMealCopy: Sendable {
    public static func idleLabel(period: String) -> String {
        "Track \(MealPeriodPill.canonical(period).lowercased())"
    }

    public static let trackingLabel = "Tracking"

    /// One-line subtitle under the chip.
    public static let subtitle = "Adds this meal to My Plate"

    public static let firstTapTip = "Adds this meal’s items to My Plate and today’s calories."

    public static func accessibilityIdle(period: String) -> String {
        "Track \(MealPeriodPill.canonical(period)) — add this meal to My Plate"
    }

    public static func accessibilityTracking(period: String) -> String {
        "Stop tracking \(MealPeriodPill.canonical(period))"
    }
}

/// Favorites on the live board — the meal items Track Meal should add.
public enum TrackMealPlateItems: Sendable {
    public static func favorites(
        from stations: [MenuStation],
        favoriteNames: Set<String>
    ) -> [MenuItem] {
        guard !favoriteNames.isEmpty else { return [] }
        var seen = Set<String>()
        var items: [MenuItem] = []
        for station in stations {
            for item in station.items {
                let key = item.name
                guard favoriteNames.contains(key), seen.insert(key).inserted else { continue }
                items.append(item)
            }
        }
        return items
    }
}
