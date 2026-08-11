import Foundation

/// Which meal Today's Menu should show — open now, next today, or after-hours empty.
/// Never falls back to last night's Dinner overnight (that left a bogus ~22h timer).
public enum TodaysMenuPeriodPick {
    public struct Choice: Equatable, Sendable {
        /// Primary pill ("Breakfast" / "Lunch" / "Dinner") or empty after hours.
        public let period: String
        /// Raw API period name used for window matching.
        public let livePeriodName: String
        /// End of the meal currently being served (nil when not in a window).
        public let endsAtMinutes: Int?
        /// Start of the next meal still ahead today (widget reload boundary).
        public let upcomingStartMinutes: Int?
        /// Past last meal — show empty, not stale Dinner.
        public let isAfterHours: Bool

        public init(
            period: String,
            livePeriodName: String,
            endsAtMinutes: Int?,
            upcomingStartMinutes: Int?,
            isAfterHours: Bool
        ) {
            self.period = period
            self.livePeriodName = livePeriodName
            self.endsAtMinutes = endsAtMinutes
            self.upcomingStartMinutes = upcomingStartMinutes
            self.isAfterHours = isAfterHours
        }
    }

    public static func choose(
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String],
        nowMinutes: Int
    ) -> Choice {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        let timed = timedPeriods.filter { $0.startMinutes != nil && $0.endMinutes != nil }

        if let current = timed.first(where: {
            nowMinutes >= $0.startMinutes! && nowMinutes < $0.endMinutes!
        }) {
            return Choice(
                period: primaryPill(for: current.name, pills: pills),
                livePeriodName: current.name,
                endsAtMinutes: current.endMinutes,
                upcomingStartMinutes: nil,
                isAfterHours: false
            )
        }

        if let upcoming = timed
            .filter({ $0.startMinutes! > nowMinutes })
            .min(by: { $0.startMinutes! < $1.startMinutes! })
        {
            return Choice(
                period: primaryPill(for: upcoming.name, pills: pills),
                livePeriodName: upcoming.name,
                endsAtMinutes: nil,
                upcomingStartMinutes: upcoming.startMinutes,
                isAfterHours: false
            )
        }

        return Choice(
            period: "",
            livePeriodName: "",
            endsAtMinutes: nil,
            upcomingStartMinutes: nil,
            isAfterHours: !timed.isEmpty
        )
    }

    private static func primaryPill(for liveName: String, pills: [String]) -> String {
        let lower = liveName.lowercased()
        if lower.contains("brunch") || lower.contains("breakfast"), pills.contains("Breakfast") {
            return "Breakfast"
        }
        if lower.contains("lunch"), pills.contains("Lunch") { return "Lunch" }
        if lower.contains("dinner"), pills.contains("Dinner") { return "Dinner" }
        return pills.first ?? liveName
    }
}
