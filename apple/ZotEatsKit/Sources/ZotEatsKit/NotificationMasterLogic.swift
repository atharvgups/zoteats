import Foundation

/// Master Notifications switch vs Advanced per-type flags.
/// Turning the master on the first time enables the calm default set.
/// Later Advanced edits stick when the master is toggled off and on.
public enum NotificationMasterLogic: Sendable {
    public static let masterKey = "zoteats.alerts.master"
    public static let customizedKey = "zoteats.alerts.advancedCustomized"

    /// Unset master follows any already-on child (TestFlight migration).
    public static func masterEnabled(stored: Bool?, anyChildEnabled: Bool) -> Bool {
        if let stored { return stored }
        return anyChildEnabled
    }

    /// First time the master flips on, with no Advanced edits yet, turn the useful set on.
    public static func shouldApplySensibleDefaults(
        masterJustEnabled: Bool,
        advancedCustomized: Bool,
        anyChildEnabled: Bool
    ) -> Bool {
        masterJustEnabled && !advancedCustomized && !anyChildEnabled
    }
}
