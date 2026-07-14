import Foundation

/// Date/time helpers pinned to UCI's timezone (America/Los_Angeles),
/// so hours and "open now" logic are correct no matter where the device is.
enum PacificTime {
    static let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// Today's date in Irvine as YYYY-MM-DD.
    static func todayISO(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    /// Minutes since midnight in Irvine.
    static func nowMinutes(now: Date = Date()) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// Weekday name in Irvine, e.g. "Monday".
    static func weekdayName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: now)
    }

    /// "HH:mm" (or "HH:mm:ss") -> minutes since midnight.
    static func parseMinutes(_ time: String?) -> Int? {
        guard let time else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard let hours = parts.first else { return nil }
        let minutes = parts.count > 1 ? parts[1] : 0
        return hours * 60 + minutes
    }

    /// Minutes since midnight -> "7:15 AM".
    static func formatMinutes(_ mins: Int) -> String {
        let hour = mins / 60
        let minute = mins % 60
        let period = (hour < 12 || hour == 24) ? "AM" : "PM"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return minute == 0
            ? "\(display):00 \(period)"
            : "\(display):\(String(format: "%02d", minute)) \(period)"
    }
}
