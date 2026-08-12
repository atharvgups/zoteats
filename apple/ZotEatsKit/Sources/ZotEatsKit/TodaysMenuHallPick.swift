import Foundation

/// Which dining hall Today's Menu Auto should show.
/// Prefer a hall serving now; between meals, the soonest `openingLater`
/// (not API-first, which pinned a closed commons and hid the next meal).
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

        return locations.first
    }
}
