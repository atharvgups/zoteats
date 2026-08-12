import Foundation

/// Lock-screen / Island copy for the meal-end Live Activity.
public enum MealCountdownChrome {
    public static func hasEnded(endsAt: Date, now: Date = Date()) -> Bool {
        now >= endsAt
    }

    /// Lock-screen secondary line under the hall name.
    /// After close, matches Island / Status destination chrome (next meal,
    /// tomorrow, Fri→Mon weekday) — not a dead-end "Dinner has ended".
    public static func lockStatus(
        period: String,
        hasEnded: Bool,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        now: Date = Date()
    ) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hasEnded {
            return meal.isEmpty ? "Ends in" : "\(meal) ends in"
        }
        let endedPrefix = meal.isEmpty ? "Meal has ended" : "\(meal) has ended"
        return postCloseLine(
            endedPrefix: endedPrefix,
            trackedMeal: meal,
            postClosePeriod: postClosePeriod,
            postCloseDate: postCloseDate,
            now: now
        )
    }

    /// Expanded Island bottom line — after close, match the post-close deep link
    /// (next meal / tomorrow / last posted while awaiting). Never say
    /// "see what's next" when tap reopens the same meal or has nowhere to go.
    /// Beyond-tomorrow opens (Fri→Mon) name the weekday like Status
    /// (`"Breakfast Monday"`), not a misleading `"Breakfast next"`.
    public static func islandBottom(
        period: String,
        hasEnded: Bool,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        now: Date = Date()
    ) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hasEnded {
            if meal.isEmpty {
                return "Wrapping up — grab a bite while you can"
            }
            return "\(meal) is wrapping up — grab a bite while you can"
        }

        let endedPrefix = meal.isEmpty ? "This meal has ended" : "\(meal) has ended"
        return postCloseLine(
            endedPrefix: endedPrefix,
            trackedMeal: meal,
            postClosePeriod: postClosePeriod,
            postCloseDate: postCloseDate,
            now: now
        )
    }

    /// Shared Lock / Island post-close destination line so the surfaces can't drift.
    private static func postCloseLine(
        endedPrefix: String,
        trackedMeal: String,
        postClosePeriod: String?,
        postCloseDate: String?,
        now: Date
    ) -> String {
        let nextRaw = postClosePeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextDate = postCloseDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !nextRaw.isEmpty else {
            return endedPrefix
        }

        let nextPill = MealPeriodPill.canonical(nextRaw)
        let trackedPill = trackedMeal.isEmpty ? "" : MealPeriodPill.canonical(trackedMeal)

        // Partial board: post-close keeps last posted meal (1.0.185) — Status parity.
        if !trackedPill.isEmpty,
           nextPill.caseInsensitiveCompare(trackedPill) == .orderedSame,
           nextDate.isEmpty
        {
            return "\(endedPrefix) — more meals post later"
        }

        if !nextDate.isEmpty {
            let tomorrowISO = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
            if let tomorrowISO, nextDate == tomorrowISO {
                return "\(endedPrefix) — \(nextPill) next"
            }
            if let weekday = weekdayName(isoDate: nextDate) {
                return "\(endedPrefix) — \(nextPill) \(weekday)"
            }
            return "\(endedPrefix) — \(nextPill) next"
        }
        return "\(endedPrefix) — \(nextPill) is next"
    }

    /// Irvine weekday for a YYYY-MM-DD board date (Status `"Breakfast Monday"`).
    private static func weekdayName(isoDate: String) -> String? {
        let formatter = DateFormatter()
        formatter.timeZone = PacificTime.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate) else { return nil }
        return PacificTime.weekdayName(now: date)
    }
}
