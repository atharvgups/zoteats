import Foundation

/// Pure planning logic for "tell me when this spot opens" notifications.
/// The app feeds it today's dining halls and campus venues plus the user's
/// watchlist; it returns concrete fire times for local notifications.
/// Kept in the Kit so the scheduling brain is unit-testable on Linux.
public enum OpeningAlertPlanner {
    /// A place the user can watch. `opensAtMinutes` is nil when the place is
    /// already open or doesn't open again today.
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let name: String
        public let opensAtMinutes: Int?

        public init(id: String, name: String, opensAtMinutes: Int?) {
            self.id = id
            self.name = name
            self.opensAtMinutes = opensAtMinutes
        }
    }

    public struct PlannedAlert: Sendable, Equatable {
        /// "open:<placeID>:<dateISO>" — stable per place per day, so
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

    /// Alerts for every watched place that opens later today (Irvine time).
    /// Places already open, unwatched, or done for the day produce nothing.
    public static func plan(
        candidates: [Candidate],
        watchedIDs: Set<String>,
        now: Date = Date()
    ) -> [PlannedAlert] {
        let nowMinutes = PacificTime.nowMinutes(now: now)
        let dateISO = PacificTime.todayISO(now: now)
        let midnight = PacificTime.calendar.startOfDay(for: now)

        return candidates.compactMap { candidate in
            guard watchedIDs.contains(candidate.id),
                  let opensAt = candidate.opensAtMinutes,
                  opensAt > nowMinutes
            else { return nil }
            return PlannedAlert(
                identifier: "open:\(candidate.id):\(dateISO)",
                placeID: candidate.id,
                placeName: candidate.name,
                fireDate: midnight.addingTimeInterval(TimeInterval(opensAt * 60))
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// A dining hall's next opening today: the earliest meal period that
    /// hasn't started yet. Nil while open or after the last meal.
    public static func nextOpening(periods: [MealPeriodWindow], nowMinutes: Int) -> Int? {
        let upcoming = periods.compactMap(\.startMinutes).filter { $0 > nowMinutes }
        guard let next = upcoming.min() else { return nil }
        // If a period is currently being served, the hall is open — no alert.
        let openNow = periods.contains {
            guard let start = $0.startMinutes, let end = $0.endMinutes else { return false }
            return nowMinutes >= start && nowMinutes < end
        }
        return openNow ? nil : next
    }
}
