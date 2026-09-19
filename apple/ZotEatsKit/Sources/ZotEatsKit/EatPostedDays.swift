import Foundation

/// A day chip on Eat’s picker — today always, plus future calendar days.
public struct EatPostedDay: Equatable, Sendable, Identifiable {
    public var id: String { isoDate }
    public let isoDate: String
    public let label: String
    public let accessibilityLabel: String
    /// First future chip when one or more days after today have no board.
    public let skipsAhead: Bool
    /// Known posted board. Unknown (probe still running) counts as posted so
    /// chips don't dim, then pop.
    public let hasPostedMenu: Bool

    public init(
        isoDate: String,
        label: String,
        accessibilityLabel: String,
        skipsAhead: Bool,
        hasPostedMenu: Bool = true
    ) {
        self.isoDate = isoDate
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.skipsAhead = skipsAhead
        self.hasPostedMenu = hasPostedMenu
    }
}

/// Days Eat should offer in the day picker — Today, Tomorrow, then each
/// following calendar day in a calm horizontal scroll. Unposted days stay
/// selectable so someone can peek ahead.
public enum EatPostedDays {
    /// First window — a few chips on screen, the rest a short scroll away.
    public static let initialHorizonDays = 21
    /// Appended when the strip is scrolled near the end.
    public static let horizonStep = 14
    public static let maxHorizonDays = 90

    public static func extendedHorizon(_ current: Int) -> Int {
        min(maxHorizonDays, max(initialHorizonDays, current) + horizonStep)
    }

    public static func visible(
        candidates: [(isoDate: String, label: String)],
        todayISO: String,
        postedISOs: Set<String>?
    ) -> [EatPostedDay] {
        guard !candidates.isEmpty else { return [] }

        let ordered = candidates.sorted { $0.isoDate < $1.isoDate }
        return ordered.enumerated().map { index, day in
            let previousISO = index > 0 ? ordered[index - 1].isoDate : todayISO
            let skipsAhead = index > 0
                && day.isoDate != todayISO
                && skipsCalendarDays(from: previousISO, to: day.isoDate)
            let hasPostedMenu = postedISOs.map { $0.contains(day.isoDate) } ?? true
            let label = chipLabel(isoDate: day.isoDate, todayISO: todayISO, fallback: day.label)
            let spoken = spokenLabel(isoDate: day.isoDate, todayISO: todayISO, fallback: day.label)
            let accessibilityLabel: String
            if !hasPostedMenu {
                accessibilityLabel = "\(spoken), no menu posted yet"
            } else if skipsAhead {
                accessibilityLabel = "Next posted menu, \(spoken)"
            } else {
                accessibilityLabel = "Menu for \(spoken)"
            }
            return EatPostedDay(
                isoDate: day.isoDate,
                label: skipsAhead ? "Next · \(label)" : label,
                accessibilityLabel: accessibilityLabel,
                skipsAhead: skipsAhead,
                hasPostedMenu: hasPostedMenu
            )
        }
    }

    /// Today / Tomorrow, then a short "Mon 21" so the strip stays calm.
    public static func chipLabel(isoDate: String, todayISO: String, fallback: String) -> String {
        if isoDate == todayISO { return "Today" }
        if calendarDays(from: todayISO, to: isoDate) == 1 { return "Tomorrow" }
        return compactWeekdayDay(isoDate) ?? fallback
    }

    public static func spokenLabel(isoDate: String, todayISO: String, fallback: String) -> String {
        if isoDate == todayISO { return "Today" }
        if calendarDays(from: todayISO, to: isoDate) == 1 { return "Tomorrow" }
        return verboseWeekday(isoDate) ?? fallback
    }

    public static func compactWeekdayDay(_ isoDate: String) -> String? {
        formatted(isoDate, format: "EEE d")
    }

    public static func verboseWeekday(_ isoDate: String) -> String? {
        formatted(isoDate, format: "EEEE, MMM d")
    }

    /// Inclusive Irvine ISO dates from `from` through `through`.
    public static func isoDates(from: String, through: String) -> [String] {
        var result: [String] = []
        var iso = from
        var steps = 0
        while iso <= through, steps < 28 {
            result.append(iso)
            guard let next = UCITime.nextISO(after: iso) else { break }
            iso = next
            steps += 1
        }
        return result
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

    private static func formatted(_ isoDate: String, format: String) -> String? {
        let parser = DateFormatter()
        parser.calendar = PacificTime.calendar
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = PacificTime.timeZone
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDate) else { return nil }
        let out = DateFormatter()
        out.calendar = PacificTime.calendar
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = PacificTime.timeZone
        out.dateFormat = format
        return out.string(from: date)
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
            return "No \(meal.lowercased()) posted for this day yet. Try another meal, or pick another day above."
        }
        if meal.isEmpty {
            return "This hall hasn’t posted a menu yet. Check back soon."
        }
        return "This hall hasn’t published \(meal.lowercased()) yet. Check back soon."
    }
}
