import Foundation

/// Build the Gym “This week’s hours” list — maintained schedule for other
/// days, but today’s row matches live Waitz (`todayHours` / Closed-until)
/// so the bold today highlight can’t contradict the hero.
public enum GymWeekHours {
    /// Normalized Waitz range for week-card display (`"6:00 AM – 12:00 PM"`).
    public static func displayRange(_ summary: String?) -> String? {
        guard let bounds = WaitzHoursSummary.rangeBounds(summary) else { return nil }
        return "\(UCITime.format(minutes: bounds.open)) – \(UCITime.format(minutes: bounds.close))"
    }

    public static func resolve(
        weekday: String,
        todayHours: String?,
        openNow: Bool,
        usingLiveRange: Bool,
        waitzReopenMinutes: Int?,
        nowMinutes: Int,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> [DayHours] {
        arcWeek.map { day in
            let schedule = "\(GymService.formatHour(day.open)) – \(GymService.formatHour(day.close))"
            guard day.day == weekday else {
                return DayHours(day: day.day, hours: schedule)
            }

            if usingLiveRange {
                if let display = displayRange(todayHours) ?? todayHours {
                    return DayHours(day: day.day, hours: display)
                }
                return DayHours(day: day.day, hours: schedule)
            }

            if !openNow, let reopen = waitzReopenMinutes {
                let line = nowMinutes < reopen
                    ? "Opens at \(UCITime.format(minutes: reopen))"
                    : "Opens tomorrow at \(UCITime.format(minutes: reopen))"
                return DayHours(day: day.day, hours: line)
            }

            return DayHours(day: day.day, hours: schedule)
        }
    }
}
