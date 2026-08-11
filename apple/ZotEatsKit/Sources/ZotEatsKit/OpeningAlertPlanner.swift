import Foundation

/// Pure planning logic for "tell me when this spot opens" notifications.
/// The app feeds it today's dining halls and campus venues plus the user's
/// watchlist; it returns concrete fire times for local notifications.
/// Kept in the Kit so the scheduling brain is unit-testable on Linux.
public enum OpeningAlertPlanner {
    /// A place the user can watch. `opensAtMinutes` is on the calendar day
    /// identified by `dayOffset` (0 = today, 1 = tomorrow).
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let name: String
        public let opensAtMinutes: Int?
        /// 0 = today (Irvine), 1 = tomorrow — used after "closed for today".
        public let dayOffset: Int

        public init(id: String, name: String, opensAtMinutes: Int?, dayOffset: Int = 0) {
            self.id = id
            self.name = name
            self.opensAtMinutes = opensAtMinutes
            self.dayOffset = max(0, dayOffset)
        }
    }

    public struct PlannedAlert: Sendable, Equatable {
        /// "open:<placeID>:<dateISO>" — stable per place per fire-day, so
        /// rescheduling replaces rather than duplicates.
        public let identifier: String
        public let placeID: String
        public let placeName: String
        public let fireDate: Date

        public init(identifier: String, placeID: String, placeName: String, fireDate: Date) {
            self.identifier = identifier
            self.placeID = placeID
            self.placeName = placeName
            self.fireDate = fireDate
        }
    }

    /// Alerts for every watched place that opens later today **or** tomorrow
    /// (next meal while already open, or morning after today's windows end).
    public static func plan(
        candidates: [Candidate],
        watchedIDs: Set<String>,
        now: Date = Date()
    ) -> [PlannedAlert] {
        let nowMinutes = PacificTime.nowMinutes(now: now)
        let calendar = PacificTime.calendar
        let startOfToday = calendar.startOfDay(for: now)

        return candidates.compactMap { candidate -> PlannedAlert? in
            guard watchedIDs.contains(candidate.id),
                  let opensAt = candidate.opensAtMinutes
            else { return nil }

            if candidate.dayOffset == 0 {
                // Still today — only schedule openings that haven't started yet.
                guard opensAt > nowMinutes else { return nil }
            }

            guard let day = calendar.date(byAdding: .day, value: candidate.dayOffset, to: startOfToday)
            else { return nil }
            let fireDate = day.addingTimeInterval(TimeInterval(opensAt * 60))
            // Identifier keys off the fire-day ISO so an evening reschedule
            // for tomorrow replaces the same slot after midnight.
            let dateISO = PacificTime.todayISO(now: fireDate)
            return PlannedAlert(
                identifier: "open:\(candidate.id):\(dateISO)",
                placeID: candidate.id,
                placeName: candidate.name,
                fireDate: fireDate
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// A dining hall's next *reopen* today: earliest meal start still ahead,
    /// but nil while a period is being served (hall is already open).
    public static func nextOpening(periods: [MealPeriodWindow], nowMinutes: Int) -> Int? {
        let openNow = periods.contains {
            guard let start = $0.startMinutes, let end = $0.endMinutes else { return false }
            return nowMinutes >= start && nowMinutes < end
        }
        return openNow ? nil : followingOpening(periods: periods, nowMinutes: nowMinutes)
    }

    /// Earliest meal start still ahead today — even while lunch/dinner is
    /// already being served. Used so watching during lunch still schedules dinner.
    public static func followingOpening(periods: [MealPeriodWindow], nowMinutes: Int) -> Int? {
        periods.compactMap(\.startMinutes).filter { $0 > nowMinutes }.min()
    }

    /// Earliest meal start on a day of periods (e.g. tomorrow's breakfast).
    public static func earliestOpening(periods: [MealPeriodWindow]) -> Int? {
        periods.compactMap(\.startMinutes).min()
    }
}
