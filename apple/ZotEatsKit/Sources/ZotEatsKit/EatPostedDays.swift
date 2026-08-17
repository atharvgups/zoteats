import Foundation

/// A day chip on Eat’s picker — today always, plus future days with a board.
public struct EatPostedDay: Equatable, Sendable, Identifiable {
    public var id: String { isoDate }
    public let isoDate: String
    public let label: String
    public let accessibilityLabel: String
    /// First future chip when one or more days after today have no board.
    public let skipsAhead: Bool

    public init(
        isoDate: String,
        label: String,
        accessibilityLabel: String,
        skipsAhead: Bool
    ) {
        self.isoDate = isoDate
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.skipsAhead = skipsAhead
    }
}

/// Days Eat should offer in the day picker — today always, future days only
/// when that hall actually has a posted board (not every day inside `/dateRange`).
public enum EatPostedDays {
    public static func visible(
        candidates: [(isoDate: String, label: String)],
        todayISO: String,
        postedISOs: Set<String>?
    ) -> [EatPostedDay] {
        let filtered = candidates.filter { day in
            if day.isoDate == todayISO { return true }
            guard let postedISOs else { return false }
            return postedISOs.contains(day.isoDate)
        }
        return filtered.enumerated().map { index, day in
            let skipsAhead = index > 0
                && day.isoDate != todayISO
                && skipsCalendarDays(from: todayISO, to: day.isoDate)
                && !filtered.prefix(index).contains { $0.isoDate != todayISO }
            let label = skipsAhead ? "Next · \(day.label)" : day.label
            let accessibilityLabel = skipsAhead
                ? "Next posted menu, \(day.label)"
                : "Menu for \(day.label)"
            return EatPostedDay(
                isoDate: day.isoDate,
                label: label,
                accessibilityLabel: accessibilityLabel,
                skipsAhead: skipsAhead
            )
        }
    }

    /// True when `to` is at least two Irvine calendar days after `from`.
    public static func skipsCalendarDays(from: String, to: String) -> Bool {
        (calendarDays(from: from, to: to) ?? 0) > 1
    }

    public static func calendarDays(from: String, to: String) -> Int? {
        let formatter = DateFormatter()
        formatter.calendar = PacificTime.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = PacificTime.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: from),
              let end = formatter.date(from: to)
        else { return nil }
        return PacificTime.calendar.dateComponents([.day], from: start, to: end).day
    }

    /// Caption when the open board skipped empty midweek days.
    public static func browseCaption(period: String, prettyDate: String, skipsAhead: Bool) -> String {
        if skipsAhead {
            return "\(period) • next posted · \(prettyDate)"
        }
        return "\(period) • \(prettyDate)"
    }
}

/// Honest empty copy when a browsed day/meal has no dishes — no jargon.
public enum EatBrowseEmptyCopy {
    public static func message(period: String, browsingFutureDay: Bool) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if browsingFutureDay {
            if meal.isEmpty {
                return "UCI hasn’t posted a menu for this day yet. Pick another day above."
            }
            return "No \(meal.lowercased()) on the board for this day. Try another meal, or pick another day above."
        }
        if meal.isEmpty {
            return "This hall hasn’t posted a menu yet. Check back soon."
        }
        return "This hall hasn’t published \(meal.lowercased()) yet. Check back soon."
    }
}
