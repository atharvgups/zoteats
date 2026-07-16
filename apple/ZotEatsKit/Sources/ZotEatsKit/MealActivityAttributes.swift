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

    public init(hallName: String, period: String) {
        self.hallName = hallName
        self.period = period
    }
}
#endif
