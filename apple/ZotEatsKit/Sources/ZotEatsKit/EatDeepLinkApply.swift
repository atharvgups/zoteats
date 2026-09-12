import Foundation

/// Apply outcome for Eat deep links — unknown hall ids must discard (no period/dish
/// side effects on the wrong hall), and a failed locations feed must clear pending
/// instead of waiting forever (CampusDeepLinkApply parity).
public enum EatDeepLinkApply {
    public enum Outcome: Equatable, Sendable {
        /// Locations still loading — keep the pending link.
        case waitForLocations
        /// Failed feed, or a hall was named but isn't in the feed.
        case discard
        /// Apply the link. `hallID` is set when the link named a known hall.
        case apply(hallID: String?)
    }

    /// - Parameter needsLocations: True when the link carries hall and/or period
    ///   (dish-only / bare eat can apply without the feed).
    /// - Parameter feedReady: True once locations finished loading or failed.
    public static func resolve(
        hallID: String?,
        needsLocations: Bool,
        locations: [DiningLocation]?,
        feedReady: Bool
    ) -> Outcome {
        if !needsLocations {
            return .apply(hallID: nil)
        }
        guard feedReady else { return .waitForLocations }
        guard let locations else { return .discard }

        if let hallID, !hallID.isEmpty {
            if locations.contains(where: { $0.id == hallID }) {
                return .apply(hallID: hallID)
            }
            return .discard
        }
        // Period-only (or date) after the feed is ready — keep current hall.
        return .apply(hallID: nil)
    }
}
