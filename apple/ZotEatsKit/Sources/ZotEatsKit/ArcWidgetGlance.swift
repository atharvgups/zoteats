import Foundation

/// Pure glance payload for the ARC Gym widget — live sensors when Waitz
/// tracks the ARC, otherwise the same typical estimate the Gym tab shows.
public enum ArcWidgetGlance {
    public struct Crowding: Equatable, Sendable {
        public let percent: Int
        public let isTypical: Bool

        public init(percent: Int, isTypical: Bool) {
            self.percent = percent
            self.isTypical = isTypical
        }

        /// Short chrome label: "live" vs "typical".
        public var sourceLabel: String {
            isTypical ? "typical" : "live"
        }
    }

    public static func crowding(from status: GymStatus) -> Crowding? {
        guard let point = status.busyness, let percent = point.percent else { return nil }
        return Crowding(percent: percent, isTypical: point.source == .typical)
    }
}
