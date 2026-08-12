import Foundation

/// Parse Waitz `hourSummary` strings. While open the feed often says `"open"`;
/// while closed it usually ships the real reopen (`"Closed until 8:00am"`).
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
