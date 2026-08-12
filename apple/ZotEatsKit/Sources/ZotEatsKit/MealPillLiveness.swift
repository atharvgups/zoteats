import Foundation

/// Whether a primary meal pill (Breakfast / Lunch / Dinner) is still live or
/// upcoming today — window end has not passed. Shared by Eat sticky selection
/// and Eat deep links so ended meals fall through to the next period.
public enum MealPillLiveness {
    public static func isLiveOrUpcoming(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String],
        nowMinutes: Int
    ) -> Bool {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        return isLiveOrUpcoming(
            pill: pill,
            timedPeriods: timedPeriods,
            pills: pills,
            nowMinutes: nowMinutes
        )
    }

    public static func isLiveOrUpcoming(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        pills: [String],
        nowMinutes: Int
    ) -> Bool {
        for window in timedPeriods {
            guard let end = window.endMinutes else { continue }
            let windowPill = primaryPill(for: window.name, pills: pills)
            guard windowPill.caseInsensitiveCompare(pill) == .orderedSame else { continue }
            if nowMinutes < end { return true }
        }
        return false
    }

    private static func primaryPill(for liveName: String, pills: [String]) -> String {
        let lower = liveName.lowercased()
        if lower.contains("brunch") || lower.contains("breakfast"), pills.contains("Breakfast") {
            return "Breakfast"
        }
        if lower.contains("lunch"), pills.contains("Lunch") { return "Lunch" }
        if lower.contains("dinner"), pills.contains("Dinner") { return "Dinner" }
        return pills.first { liveName.caseInsensitiveCompare($0) == .orderedSame } ?? liveName
    }
}
