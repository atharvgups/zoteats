#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Shared contract between the app (which starts the Live Activity) and the
/// widget extension (which renders it): "this meal at this hall ends at X".
public struct MealActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the tracked meal period ends; the UI counts down to it.
        public var endsAt: Date

        public init(endsAt: Date) {
            self.endsAt = endsAt
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
