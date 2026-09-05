import Foundation

/// Dining Halls widget status — meal + clock, no countdown filler.
public enum DiningStatusWidgetLine {
    public static func resolve(
        state: HallOpenState,
        todayHours: String?,
        opensTomorrowAtMinutes: Int?,
        opensTomorrowPeriod: String?,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        opensNextPeriod: String? = nil,
        compact: Bool = false
    ) -> String {
        let clock: (Int) -> String = { minutes in
            let value = minutes % (24 * 60)
            return compact ? UCITime.formatCompact(minutes: value) : UCITime.format(minutes: value)
        }
        switch state {
        case .open(let period, let closesAt):
            return "\(period) · \(clock(closesAt))"
        case .openingLater(let period, let opensAt):
            return "\(period) · \(clock(opensAt))"
        case .awaitingMoreMeals:
            return compact ? "More later" : "More meals post later"
        case .closedForToday:
            if let open = opensTomorrowAtMinutes {
                let meal = opensTomorrowPeriod ?? "Opens"
                return "\(meal) tomorrow · \(clock(open))"
            }
            if let open = opensNextAtMinutes,
               let weekday = opensNextWeekday,
               !weekday.isEmpty {
                let meal = opensNextPeriod ?? "Opens"
                return "\(meal) \(weekday) · \(clock(open))"
            }
            return compact ? "Closed" : "Closed for today"
        case .unknown:
            _ = todayHours
            return compact ? "Not posted" : "Menu not posted yet"
        }
    }

    /// Squeeze a full widget line onto a small tile ("8:00 PM" → "8PM").
    public static func tighten(_ line: String) -> String {
        line
            .replacingOccurrences(of: ":00 ", with: "")
            .replacingOccurrences(of: " AM", with: "AM")
            .replacingOccurrences(of: " PM", with: "PM")
    }

    /// Split `"Lunch · 11:30 AM"` into meal + clock for Box Box-style rows.
    public static func splitMealAndClock(_ line: String) -> (meal: String, clock: String?) {
        let parts = line.split(separator: "·", maxSplits: 1, omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return (line, nil)
        }
        return (parts[0], parts[1])
    }
}
