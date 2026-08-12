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
        /// Published windows ended but Dinner may still drop today.
        public let isAwaitingMoreMeals: Bool

        public init(
            period: String,
            livePeriodName: String,
            endsAtMinutes: Int?,
            upcomingStartMinutes: Int?,
            isAfterHours: Bool,
            isAwaitingMoreMeals: Bool = false
        ) {
            self.period = period
            self.livePeriodName = livePeriodName
            self.endsAtMinutes = endsAtMinutes
            self.upcomingStartMinutes = upcomingStartMinutes
            self.isAfterHours = isAfterHours
            self.isAwaitingMoreMeals = isAwaitingMoreMeals
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
                period: MealPeriodPill.match(current.name, in: pills) ?? current.name,
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
                period: MealPeriodPill.match(upcoming.name, in: pills) ?? upcoming.name,
                livePeriodName: upcoming.name,
                endsAtMinutes: nil,
                upcomingStartMinutes: upcoming.startMinutes,
                isAfterHours: false
            )
        }

        let awaiting = DiningBoardPublish.awaitingLaterMeals(
            periods: timedPeriods,
            nowMinutes: nowMinutes
        )
        // Empty timed board mid-day stays not-after-hours (Menu not posted yet).
        // After evening confidence — including empty/unpublished boards — treat
        // as after-hours so widgets can show tomorrow / Monday next-open copy.
        let afterHours = !awaiting && (
            !timed.isEmpty || nowMinutes >= DiningBoardPublish.eveningConfidenceMinutes
        )
        return Choice(
            period: "",
            livePeriodName: "",
            endsAtMinutes: nil,
            upcomingStartMinutes: nil,
            isAfterHours: afterHours,
            isAwaitingMoreMeals: awaiting
        )
    }
}
