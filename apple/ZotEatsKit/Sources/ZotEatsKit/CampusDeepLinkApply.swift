import Foundation

/// Apply outcome for Campus place deep links — unknown ids (and failed feeds)
/// must discard so `pendingDeepLink` doesn't retry forever on every view update.
public enum CampusDeepLinkApply {
    public enum Outcome: Equatable, Sendable {
        /// Places feed still loading — keep the pending link.
        case waitForPlaces
        /// Bare campus URL, failed feed, or loaded feed with no matching place.
        case discard
        /// Open the matching place sheet.
        case open(placeID: String)
    }

    /// - Parameter feedReady: True once places finished loading or failed.
    public static func resolve(
        placeID: String?,
        places: [CampusPlace]?,
        feedReady: Bool
    ) -> Outcome {
        guard let placeID, !placeID.isEmpty else { return .discard }
        guard feedReady else { return .waitForPlaces }
        guard let places else { return .discard }
        if places.contains(where: { $0.id == placeID }) {
            return .open(placeID: placeID)
        }
        return .discard
    }
}
