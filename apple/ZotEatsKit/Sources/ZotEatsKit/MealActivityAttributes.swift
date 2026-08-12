#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Shared contract between the app (which starts the Live Activity) and the
/// widget extension (which renders it): "this meal at this hall ends at X".
public struct MealActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the tracked meal period ends; the UI counts down to it.
        public var endsAt: Date
        /// Live meal name for tomorrow's first open (Brunch / Breakfast) — used
        /// after `endsAt` so Island taps jump to tomorrow instead of a dead pill.
        public var opensTomorrowPeriod: String?

        public init(endsAt: Date, opensTomorrowPeriod: String? = nil) {
            self.endsAt = endsAt
            self.opensTomorrowPeriod = opensTomorrowPeriod
        }
    }

    public let hallName: String
    public let period: String
    /// Stable Anteater API hall id (`anteatery`, `brandywine`, …). Optional so
    /// activities started before this field still decode on cold start.
    public let hallID: String?

    public init(hallName: String, period: String, hallID: String? = nil) {
        self.hallName = hallName
        self.period = period
        self.hallID = hallID
    }
}
#endif
