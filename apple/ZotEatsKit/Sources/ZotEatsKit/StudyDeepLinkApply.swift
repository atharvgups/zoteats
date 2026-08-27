import Foundation

/// Apply outcome for Study facility deep links — unknown ids must discard (and
/// clear any pin) so Quietest auto-expand isn't suppressed for the session;
/// failed feeds must clear pending instead of waiting forever (Campus/Eat parity).
public enum StudyDeepLinkApply {
    public enum Outcome: Equatable, Sendable {
        /// Facilities still loading — keep the pending link.
        case waitForFacilities
        /// Failed feed, or a facility was named but isn't in the feed.
        case discard
        /// Apply the link. `facilityID` nil = bare Study / Libraries closed (clear pin).
        case apply(facilityID: Int?)
    }

    /// - Parameter feedReady: True once facilities finished loading or failed.
    public static func resolve(
        facilityID: Int?,
        facilities: [BusynessPoint]?,
        feedReady: Bool
    ) -> Outcome {
        // Bare Study / Libraries closed — clear a prior pin without waiting.
        guard let facilityID else { return .apply(facilityID: nil) }
        guard feedReady else { return .waitForFacilities }
        guard let facilities else { return .discard }
        if facilities.contains(where: { $0.id == facilityID }) {
            return .apply(facilityID: facilityID)
        }
        return .discard
    }
}
