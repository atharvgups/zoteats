import Foundation

/// Next dining reopen after tomorrow within the published menu horizon —
/// Campus Fri→Mon parity when Saturday (or any gap day) has no board.
public enum DiningNextOpen {
    public struct Result: Equatable, Sendable {
        public let dayOffset: Int
        public let weekday: String
        public let dateISO: String
        public let minutes: Int
        public let period: String

        public init(
            dayOffset: Int,
            weekday: String,
            dateISO: String,
            minutes: Int,
            period: String
        ) {
            self.dayOffset = dayOffset
            self.weekday = weekday
            self.dateISO = dateISO
            self.minutes = minutes
            self.period = period
        }
    }

    /// Scan dayOffset 2…`maxDays` (clamped to `latestISO`) for the earliest timed meal.
    public static func find(
        from now: Date = Date(),
        latestISO: String?,
        maxDays: Int = 7,
        periodsForDay: (String) async -> [MealPeriodWindow]
    ) async -> Result? {
        let calendar = PacificTime.calendar
        let startOfToday = calendar.startOfDay(for: now)
        let cappedMax: Int = {
            guard let latestISO else { return maxDays }
            for offset in 2...maxDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday)
                else { continue }
                if PacificTime.todayISO(now: day) > latestISO {
                    return max(1, offset - 1)
                }
            }
            return maxDays
        }()
        guard cappedMax >= 2 else { return nil }

        for offset in 2...cappedMax {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday)
            else { continue }
            let iso = PacificTime.todayISO(now: day)
            if let latestISO, iso > latestISO { break }
            let periods = await periodsForDay(iso)
            guard let minutes = OpeningAlertPlanner.earliestOpening(periods: periods),
                  let period = periods.first(where: { $0.startMinutes == minutes })?.name
            else { continue }
            return Result(
                dayOffset: offset,
                weekday: PacificTime.weekdayName(now: day),
                dateISO: iso,
                minutes: minutes,
                period: period
            )
        }
        return nil
    }
}
