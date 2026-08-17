import Foundation

/// Public Pacific-time helpers for app-side "when" intelligence
/// (countdowns, greetings) — same clock the services use internally.
public enum UCITime {
    /// Minutes since midnight in Irvine.
    public static func nowMinutes(now: Date = Date()) -> Int {
        PacificTime.nowMinutes(now: now)
    }

    /// Minutes since midnight -> "7:15 AM".
    public static func format(minutes: Int) -> String {
        PacificTime.formatMinutes(minutes)
    }

    /// Compact countdown between two minute marks: "45m" or "1h 10m".
    public static func countdown(from now: Int, to target: Int) -> String {
        let delta = max(0, target - now)
        let hours = delta / 60
        let minutes = delta % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    /// Wall-clock `Date` for a Pacific minutes-since-midnight value.
    /// Rolls to tomorrow when `target` is earlier than `nowMinutes`.
    public static func date(forMinutes target: Int, nowMinutes: Int, now: Date = Date()) -> Date {
        let calendar = PacificTime.calendar
        let startOfDay = calendar.startOfDay(for: now)
        let minutes = ((target % (24 * 60)) + (24 * 60)) % (24 * 60)
        let dayOffset = minutes < nowMinutes ? 1 : 0
        return calendar.date(byAdding: .minute, value: minutes + dayOffset * 24 * 60, to: startOfDay) ?? now
    }

    /// Wall-clock `Date` on a future Irvine calendar day (`dayOffset` days from
    /// today) at `target` minutes since midnight — Campus Fri→Mon next-open.
    public static func date(forMinutes target: Int, dayOffset: Int, now: Date = Date()) -> Date {
        let calendar = PacificTime.calendar
        let startOfDay = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: max(0, dayOffset), to: startOfDay) ?? now
        let minutes = ((target % (24 * 60)) + (24 * 60)) % (24 * 60)
        return calendar.date(byAdding: .minute, value: minutes, to: day) ?? now
    }

    /// Hour of day in Irvine (0-23), for greetings.
    public static func hour(now: Date = Date()) -> Int {
        PacificTime.nowMinutes(now: now) / 60
    }

    /// Weekday name in Irvine, e.g. "Monday".
    public static func weekdayName(now: Date = Date()) -> String {
        PacificTime.weekdayName(now: now)
    }

    /// Today's date in Irvine as YYYY-MM-DD.
    public static func todayISO(now: Date = Date()) -> String {
        PacificTime.todayISO(now: now)
    }

    /// The next `count` days starting today (Irvine calendar), as
    /// (isoDate: "2026-07-15", label: "Today" / "Thu Jul 16" / ...).
    public static func upcomingDays(count: Int, now: Date = Date()) -> [(isoDate: String, label: String)] {
        let calendar = PacificTime.calendar
        let labelFormatter = DateFormatter()
        labelFormatter.timeZone = PacificTime.timeZone
        labelFormatter.locale = Locale(identifier: "en_US_POSIX")
        labelFormatter.dateFormat = "EEE MMM d"

        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let iso = PacificTime.todayISO(now: day)
            let label = offset == 0 ? "Today" : (offset == 1 ? "Tomorrow" : labelFormatter.string(from: day))
            return (iso, label)
        }
    }

    /// Next Irvine calendar day after an ISO date (`yyyy-MM-dd`).
    public static func nextISO(after iso: String) -> String? {
        let formatter = DateFormatter()
        formatter.timeZone = PacificTime.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let day = formatter.date(from: iso),
              let next = PacificTime.calendar.date(byAdding: .day, value: 1, to: day)
        else { return nil }
        return formatter.string(from: next)
    }

    /// Next Irvine midnight strictly after `now` — day-rollover widget reload.
    public static func nextIrvineMidnight(now: Date = Date()) -> Date {
        let calendar = PacificTime.calendar
        let startOfDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(24 * 60 * 60)
    }
}
