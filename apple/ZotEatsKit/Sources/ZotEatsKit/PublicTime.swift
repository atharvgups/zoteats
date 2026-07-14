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

    /// Hour of day in Irvine (0-23), for greetings.
    public static func hour(now: Date = Date()) -> Int {
        PacificTime.nowMinutes(now: now) / 60
    }
}
