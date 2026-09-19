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
            let windowPill = MealPeriodPill.match(window.name, in: pills) ?? window.name
            guard windowPill.caseInsensitiveCompare(pill) == .orderedSame else { continue }
            if nowMinutes < end { return true }
        }
        return false
    }

    /// True only when this pill has a published window whose end has already passed.
    /// Unposted meals (no window yet) are **not** ended — Eat keeps them sticky so
    /// students can peek Lunch/Dinner before the board publishes them.
    public static func hasEnded(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        pills: [String],
        nowMinutes: Int
    ) -> Bool {
        for window in timedPeriods {
            guard let end = window.endMinutes else { continue }
            let windowPill = MealPeriodPill.match(window.name, in: pills) ?? window.name
            guard windowPill.caseInsensitiveCompare(pill) == .orderedSame else { continue }
            if nowMinutes >= end { return true }
        }
        return false
    }

    /// True only while `now` is inside the meal's open window (not merely upcoming).
    public static func isCurrentlyServing(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String],
        nowMinutes: Int
    ) -> Bool {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        return isCurrentlyServing(
            pill: pill,
            timedPeriods: timedPeriods,
            pills: pills,
            nowMinutes: nowMinutes
        )
    }

    public static func isCurrentlyServing(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        pills: [String],
        nowMinutes: Int
    ) -> Bool {
        for window in timedPeriods {
            guard let start = window.startMinutes, let end = window.endMinutes else { continue }
            let windowPill = MealPeriodPill.match(window.name, in: pills) ?? window.name
            guard windowPill.caseInsensitiveCompare(pill) == .orderedSame else { continue }
            if nowMinutes >= start && nowMinutes < end { return true }
        }
        return false
    }
}
