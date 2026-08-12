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
    /// (`"Brunch Monday"` / `"Breakfast Monday"`), not a misleading `"… next"`.
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
        // Status / Eat chrome keep live API names (Brunch, Limited Dinner).
        let nextLabel = MealPeriodDisplay.label(live: nextRaw, pill: nextPill)

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
                return "\(endedPrefix) — \(nextLabel) next"
            }
            if let weekday = weekdayName(isoDate: nextDate) {
                return "\(endedPrefix) — \(nextLabel) \(weekday)"
            }
            return "\(endedPrefix) — \(nextLabel) next"
        }
        return "\(endedPrefix) — \(nextLabel) is next"
    }

    /// Compact Island trailing after close — short destination hint, not bare
    /// `"Done"` while the tap deep-links to Brunch / Monday / later meals.
    /// Returns `"Done"` when there is no post-close destination.
    public static func compactTrailing(
        period: String,
        hasEnded: Bool,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        now: Date = Date()
    ) -> String {
        guard hasEnded else { return "Done" }

        let trackedMeal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextRaw = postClosePeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextDate = postCloseDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !nextRaw.isEmpty else { return "Done" }

        let nextPill = MealPeriodPill.canonical(nextRaw)
        let trackedPill = trackedMeal.isEmpty ? "" : MealPeriodPill.canonical(trackedMeal)

        // Partial board awaiting later meals — tap stays on this meal.
        if !trackedPill.isEmpty,
           nextPill.caseInsensitiveCompare(trackedPill) == .orderedSame,
           nextDate.isEmpty
        {
            return "Later"
        }

        if !nextDate.isEmpty {
            let tomorrowISO = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
            if let tomorrowISO, nextDate == tomorrowISO {
                return compactMealLabel(live: nextRaw)
            }
            // Beyond tomorrow: weekday alone — meal alone would read same-day.
            if let weekday = weekdayAbbrev(isoDate: nextDate) {
                return weekday
            }
            return compactMealLabel(live: nextRaw)
        }
        return compactMealLabel(live: nextRaw)
    }

    /// Compact meal chrome — keep Brunch; shorten Limited Dinner to Dinner.
    private static func compactMealLabel(live: String) -> String {
        let pill = MealPeriodPill.canonical(live)
        let label = MealPeriodDisplay.label(live: live, pill: pill)
        if label.localizedCaseInsensitiveContains("Limited") {
            return pill
        }
        return label
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

    /// Compact Island weekday (`Mon`) for beyond-tomorrow post-close.
    private static func weekdayAbbrev(isoDate: String) -> String? {
        let parser = DateFormatter()
        parser.timeZone = PacificTime.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDate) else { return nil }
        let formatter = DateFormatter()
        formatter.timeZone = PacificTime.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
