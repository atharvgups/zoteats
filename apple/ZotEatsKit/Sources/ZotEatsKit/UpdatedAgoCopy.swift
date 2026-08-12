import Foundation

/// Shared "Updated …" relative copy for Study/Gym captions and VoiceOver.
/// Portable across Apple + Linux (no RelativeDateTimeFormatter).
public enum UpdatedAgoCopy {
    public static func relative(from date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "just now" }

        let minutes = seconds / 60
        if minutes < 60 {
            return minutes == 1 ? "1 min. ago" : "\(minutes) min. ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? "1 hr. ago" : "\(hours) hr. ago"
        }

        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }

    public static func phrase(from date: Date, now: Date = Date()) -> String {
        "Updated \(relative(from: date, now: now))"
    }
}
