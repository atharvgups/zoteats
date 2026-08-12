import Foundation

/// Parse Waitz `hourSummary` strings. While open the feed often says `"open"`
/// or a real range (`"6:00am-11:00pm"`, `"6am - 12am"`); while closed it
/// usually ships the reopen (`"Closed until 8:00am"`).
public enum WaitzHoursSummary {
    /// Irvine minutes for a `Closed until …` summary; nil for `"open"`, empty,
    /// or unparseable text.
    public static func closedUntilMinutes(_ summary: String?) -> Int? {
        guard let summary else { return nil }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let prefix = "closed until"
        guard lower.hasPrefix(prefix) else { return nil }
        let timePart = trimmed
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseClock(timePart)
    }

    /// True only when both ends of a Waitz/schedule range parse as clocks —
    /// never `"open"`, `"Closed until …"`, or a lone hyphenated word.
    public static func isDisplayableHoursRange(_ summary: String?) -> Bool {
        rangeBounds(summary) != nil
    }

    /// Open / close Irvine minutes for a continuous range string.
    public static func rangeBounds(_ summary: String?) -> (open: Int, close: Int)? {
        guard let summary else { return nil }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if closedUntilMinutes(trimmed) != nil { return nil }
        if trimmed.lowercased() == "open" { return nil }

        let parts: [String]
        if trimmed.contains("–") {
            parts = trimmed.components(separatedBy: "–")
        } else if trimmed.contains("-") {
            parts = trimmed.components(separatedBy: "-")
        } else {
            return nil
        }
        guard parts.count == 2,
              let open = parseClock(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let close = parseClock(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return (open, close)
    }

    public static func openMinutes(_ summary: String?) -> Int? {
        rangeBounds(summary)?.open
    }

    public static func closeMinutes(_ summary: String?) -> Int? {
        rangeBounds(summary)?.close
    }

    /// `"Open until 10:00 PM"` when the range close parses; nil for `"open"` /
    /// Closed-until / unparseable — never `"Open until open"`.
    public static func openUntilLine(_ summary: String?) -> String? {
        guard let close = closeMinutes(summary) else { return nil }
        return "Open until \(UCITime.format(minutes: close))"
    }

    /// Reconcile Waitz `isOpen` with hour chrome. Closed-until and displayable
    /// ranges beat a stale feed flag (ARC often stays `isOpen: true` after close).
    /// `"open"` / nil / unparseable hours still trust `feedIsOpen`.
    public static func isEffectivelyOpen(
        feedIsOpen: Bool,
        hoursSummary: String?,
        nowMinutes: Int
    ) -> Bool {
        if closedUntilMinutes(hoursSummary) != nil {
            return false
        }
        if let bounds = rangeBounds(hoursSummary) {
            // `12am` parses as 0 — treat as end-of-day midnight (1440).
            let close = bounds.close == 0 ? 24 * 60 : bounds.close
            return nowMinutes >= bounds.open && nowMinutes < close
        }
        return feedIsOpen
    }

    /// `8:00am`, `8:00 AM`, `12pm`, `10:00 PM` → minutes since midnight.
    static func parseClock(_ raw: String) -> Int? {
        let cleaned = raw
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let isPM = cleaned.hasSuffix("pm")
        let isAM = cleaned.hasSuffix("am")
        guard isPM || isAM else { return nil }
        let clock = String(cleaned.dropLast(2))
        let parts = clock.split(separator: ":")
        guard let hourPart = parts.first, let hour = Int(hourPart), (1...12).contains(hour)
        else { return nil }
        let minute: Int
        if parts.count > 1 {
            guard let m = Int(parts[1]), (0...59).contains(m) else { return nil }
            minute = m
        } else {
            minute = 0
        }
        let hour24: Int = {
            if hour == 12 { return isAM ? 0 : 12 }
            return isAM ? hour : hour + 12
        }()
        return hour24 * 60 + minute
    }
}
