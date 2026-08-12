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

    /// Expanded Island bottom line — after close, match the post-close deep link
    /// (next meal / tomorrow / last posted while awaiting). Never say
    /// "see what's next" when tap reopens the same meal or has nowhere to go.
    public static func islandBottom(
        period: String,
        hasEnded: Bool,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil
    ) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hasEnded {
            if meal.isEmpty {
                return "Wrapping up — grab a bite while you can"
            }
            return "\(meal) is wrapping up — grab a bite while you can"
        }

        let endedPrefix = meal.isEmpty ? "This meal has ended" : "\(meal) has ended"
        let nextRaw = postClosePeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextDate = postCloseDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !nextRaw.isEmpty else {
            return endedPrefix
        }

        let nextPill = MealPeriodPill.canonical(nextRaw)
        let trackedPill = meal.isEmpty ? "" : MealPeriodPill.canonical(meal)

        // Partial board: post-close keeps last posted meal (1.0.185) — Status parity.
        if !trackedPill.isEmpty,
           nextPill.caseInsensitiveCompare(trackedPill) == .orderedSame,
           nextDate.isEmpty
        {
            return "\(endedPrefix) — more meals post later"
        }

        if !nextDate.isEmpty {
            return "\(endedPrefix) — \(nextPill) next"
        }
        return "\(endedPrefix) — \(nextPill) is next"
    }
}
