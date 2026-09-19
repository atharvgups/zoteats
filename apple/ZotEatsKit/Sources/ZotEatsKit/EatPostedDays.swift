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

/// Days Eat should offer in the day picker — Today and Tomorrow always, then
/// more dates. Prefer days that actually have a board when that probe exists;
/// never collapse the strip to only two chips.
public enum EatPostedDays {
    /// Floor so the strip still shows Mon 21 / Tue 22… after Tomorrow.
    public static let minimumVisibleDays = 7

    public static func visible(
        candidates: [(isoDate: String, label: String)],
        todayISO: String,
        postedISOs: Set<String>?
    ) -> [EatPostedDay] {
        guard let today = candidates.first(where: { $0.isoDate == todayISO })
                ?? candidates.first
        else { return [] }

        let tomorrow = candidates.first { day in
            day.isoDate != today.isoDate
                && (calendarDays(from: today.isoDate, to: day.isoDate) ?? 0) == 1
        } ?? candidates.dropFirst().first

        var picked: [(isoDate: String, label: String)] = [today]
        if let tomorrow {
            picked.append(tomorrow)
        }

        let later = candidates.filter { day in
            !picked.contains { $0.isoDate == day.isoDate }
        }

        if let postedISOs {
            let postedLater = later.filter { postedISOs.contains($0.isoDate) }
            picked.append(contentsOf: postedLater)
        }

        if picked.count < minimumVisibleDays {
            for day in later where picked.count < minimumVisibleDays {
                if !picked.contains(where: { $0.isoDate == day.isoDate }) {
                    picked.append(day)
                }
            }
        }

        picked.sort { lhs, rhs in
            lhs.isoDate < rhs.isoDate
        }

        return picked.enumerated().map { index, day in
            let previousISO = index > 0 ? picked[index - 1].isoDate : todayISO
            let skipsAhead = index > 0
                && day.isoDate != todayISO
                && skipsCalendarDays(from: previousISO, to: day.isoDate)
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
