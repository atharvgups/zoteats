import Foundation

/// Study + Quietest widget empty/closed parity when every library is shut.
public enum QuietestLibraryGlance {
    public static let closedTitle = "Libraries closed"
    public static let closedDetail = "No open library floors reporting right now."

    /// Feed includes at least one Library facility (open or closed).
    public static func hasLibraryFacilities(_ facilities: [BusynessPoint]) -> Bool {
        facilities.contains { $0.category == "Library" }
    }

    /// Show the closed hero when libraries exist but none are open/reporting.
    public static func shouldShowClosed(from facilities: [BusynessPoint]) -> Bool {
        QuietestLibraryPick.best(from: facilities) == nil
            && hasLibraryFacilities(facilities)
    }
}
