import Foundation

/// Which dining hall Today's Menu Auto should show.
/// Prefer a hall serving now; between meals, the soonest `openingLater`;
/// after hours, the soonest `opensTomorrowAtMinutes` (not API-first, which
/// pinned a later-opening commons for empty copy + tomorrow deep link).
public enum TodaysMenuHallPick {
    public static func auto(
        from locations: [DiningLocation],
        nowMinutes: Int
    ) -> DiningLocation? {
        if let serving = locations.first(where: { $0.isServing(nowMinutes: nowMinutes) }) {
            return serving
        }

        let upcoming = locations.compactMap { hall -> (hall: DiningLocation, opensAt: Int)? in
            guard case .openingLater(_, let opensAt) = hall.openState(nowMinutes: nowMinutes) else {
                return nil
            }
            return (hall, opensAt)
        }
        if let soonest = upcoming.min(by: { $0.opensAt < $1.opensAt }) {
            return soonest.hall
        }

        let tomorrow = locations.compactMap { hall -> (hall: DiningLocation, opensAt: Int, dayOffset: Int)? in
            guard hall.openState(nowMinutes: nowMinutes) == .closedForToday else { return nil }
            if let opensAt = hall.opensTomorrowAtMinutes {
                return (hall, opensAt, 1)
            }
            if let opensAt = hall.opensNextAtMinutes,
               let offset = hall.opensNextDayOffset {
                return (hall, opensAt, offset)
            }
            return nil
        }
        if let soonest = tomorrow.min(by: { lhs, rhs in
            if lhs.dayOffset != rhs.dayOffset { return lhs.dayOffset < rhs.dayOffset }
            if lhs.opensAt != rhs.opensAt { return lhs.opensAt < rhs.opensAt }
            return lhs.hall.id < rhs.hall.id
        }) {
            return soonest.hall
        }

        return locations.first
    }
}
