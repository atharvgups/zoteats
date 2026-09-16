import Foundation

/// Resolve an Eat primary pill (Breakfast / Lunch / Dinner) to the live timed
/// window for Live Activity auto-start — weekend Brunch and Limited Dinner
/// share pills but not API period names, so exact name match never fired.
public enum MealTrackWindow {
    public struct Window: Equatable, Sendable {
        /// API period name shown on the Island ("Brunch", "Limited Dinner", …).
        public let livePeriodName: String
        public let startMinutes: Int
        public let endMinutes: Int

        public init(livePeriodName: String, startMinutes: Int, endMinutes: Int) {
            self.livePeriodName = livePeriodName
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
        }
    }

    public static func resolve(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String]
    ) -> Window? {
        let available = availablePeriods.isEmpty
            ? timedPeriods.map(\.name)
            : availablePeriods
        let live = DiningService.resolvePeriod(pill, available: available)
        guard let window = timedPeriods.first(where: {
            $0.name.caseInsensitiveCompare(live) == .orderedSame
        }),
        let start = window.startMinutes,
        let end = window.endMinutes
        else { return nil }
        return Window(
            livePeriodName: window.name,
            startMinutes: start,
            endMinutes: end
        )
    }
}
