import Foundation

/// Study facility chrome when Waitz keeps a last-known % after close —
/// don't imply a floor is quiet while the building is shut.
public enum StudyFacilityCrowding {
    /// Live crowding % / bar / floor expand only while the facility is open.
    public static func showsLiveCrowding(isOpen: Bool) -> Bool {
        isOpen
    }

    public static let closedLevelLabel = "Closed"
    public static let closedDetail = "Crowding updates when open"
}
