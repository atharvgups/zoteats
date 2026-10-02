import Foundation

/// Eat-tab auto-select cuts — typical Anteatery / Brandywine hours, not
/// widget Today's Menu. Weekend Brunch (11:00–16:30) must not keep the
/// Breakfast pill selected all afternoon.
public enum EatMealWindow: Sendable {
    /// Breakfast ends 11:00 on weekdays and weekends.
    public static let breakfastEndMinutes = 11 * 60
    /// Weekday lunch ends 14:30. Weekend brunch continues later, but the
    /// Lunch pill yields to Dinner once this cut has passed.
    public static let lunchEndMinutes = 14 * 60 + 30
    /// Anteatery Afternoon Snack is 14:30–16:30; Dinner starts 16:30.
    public static let afternoonSnackEndMinutes = 16 * 60 + 30
    /// Typical dinner close. Evening Snack / Late Night starts here when posted.
    public static let dinnerEndMinutes = 20 * 60

    /// In-app ticks so Eat advances at hall cuts even when Brunch is
    /// still the only live window.
    public static let autoSelectCuts = [
        breakfastEndMinutes, lunchEndMinutes, afternoonSnackEndMinutes, dinnerEndMinutes,
    ]

    /// Clock fallback used when the board is partial or Brunch is live.
    /// Stays Breakfast / Lunch / Dinner so weekend Brunch still snaps Lunch
    /// then Dinner. Live Afternoon Snack / Late Night windows win in `autoPill`.
    public static func clockPill(nowMinutes: Int) -> String {
        if nowMinutes < breakfastEndMinutes { return "Breakfast" }
        if nowMinutes < lunchEndMinutes { return "Lunch" }
        return "Dinner"
    }

    /// Primary pill for a fresh Eat snap. After-hours stays nil so Eat
    /// matches the empty board; otherwise hall hours beat Brunch→Breakfast.
    public static func autoPill(
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String],
        nowMinutes: Int
    ) -> String? {
        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timedPeriods,
            availablePeriods: availablePeriods,
            nowMinutes: nowMinutes
        )
        if choice.isAfterHours { return nil }
        return expectedPrimary(timedPeriods: timedPeriods, nowMinutes: nowMinutes)
    }

    /// True when Eat should leave this pill — published window ended, or
    /// the typical Breakfast / Lunch cut has passed (Brunch still open).
    public static func hasEnded(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        pills: [String],
        nowMinutes: Int
    ) -> Bool {
        if MealPillLiveness.hasEnded(
            pill: pill,
            timedPeriods: timedPeriods,
            pills: pills,
            nowMinutes: nowMinutes
        ) {
            return true
        }

        switch MealPeriodPill.canonical(pill) {
        case "Breakfast":
            return nowMinutes >= breakfastEndMinutes
                && !isServingTrueMeal(
                    named: "breakfast",
                    excluding: "brunch",
                    timedPeriods: timedPeriods,
                    nowMinutes: nowMinutes
                )
        case "Lunch":
            return nowMinutes >= lunchEndMinutes
                && !isServingTrueMeal(
                    named: "lunch",
                    excluding: "brunch",
                    timedPeriods: timedPeriods,
                    nowMinutes: nowMinutes
                )
        case "Afternoon Snack":
            return nowMinutes >= afternoonSnackEndMinutes
                && !isServingCanonical("Afternoon Snack", timedPeriods: timedPeriods, nowMinutes: nowMinutes)
        case "Dinner":
            return nowMinutes >= dinnerEndMinutes
                && !isServingTrueMeal(
                    named: "dinner",
                    excluding: "",
                    timedPeriods: timedPeriods,
                    nowMinutes: nowMinutes
                )
        case "Late Night":
            return !isServingCanonical("Late Night", timedPeriods: timedPeriods, nowMinutes: nowMinutes)
                && nowMinutes >= dinnerEndMinutes
        default:
            return false
        }
    }

    // MARK: - Hall hours

    static func expectedPrimary(
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> String? {
        let timed = timedPeriods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        let live = timed.filter {
            nowMinutes >= $0.startMinutes! && nowMinutes < $0.endMinutes!
        }

        if live.contains(where: { MealPeriodPill.canonical($0.name) == "Late Night" }) {
            return "Late Night"
        }
        if live.contains(where: { MealPeriodPill.canonical($0.name) == "Dinner" }) {
            return "Dinner"
        }
        if live.contains(where: { MealPeriodPill.canonical($0.name) == "Afternoon Snack" }) {
            return "Afternoon Snack"
        }
        if live.contains(where: { isTrueMealName($0.name, named: "lunch", excluding: "brunch") }) {
            return "Lunch"
        }
        if live.contains(where: { isTrueMealName($0.name, named: "breakfast", excluding: "brunch") }) {
            return "Breakfast"
        }
        if live.contains(where: { $0.name.lowercased().contains("brunch") }) {
            return clockPill(nowMinutes: nowMinutes)
        }

        if let upcoming = timed
            .filter({ $0.startMinutes! > nowMinutes })
            .min(by: { $0.startMinutes! < $1.startMinutes! })
        {
            if upcoming.name.lowercased().contains("brunch") {
                return clockPill(nowMinutes: nowMinutes)
            }
            return MealPeriodPill.canonical(upcoming.name)
        }

        return clockPill(nowMinutes: nowMinutes)
    }

    private static func isServingTrueMeal(
        named: String,
        excluding: String,
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> Bool {
        timedPeriods.contains { window in
            guard let start = window.startMinutes, let end = window.endMinutes else {
                return false
            }
            guard isTrueMealName(window.name, named: named, excluding: excluding) else {
                return false
            }
            return nowMinutes >= start && nowMinutes < end
        }
    }

    private static func isTrueMealName(_ name: String, named: String, excluding: String) -> Bool {
        let lower = name.lowercased()
        if excluding.isEmpty { return lower.contains(named) }
        return lower.contains(named) && !lower.contains(excluding)
    }

    private static func isServingCanonical(
        _ pill: String,
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> Bool {
        timedPeriods.contains { window in
            guard let start = window.startMinutes, let end = window.endMinutes else {
                return false
            }
            guard MealPeriodPill.canonical(window.name) == pill else { return false }
            return nowMinutes >= start && nowMinutes < end
        }
    }
}
