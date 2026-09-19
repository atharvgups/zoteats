/// Snapshot of the existing Settings notification categories.
/// Master on turns the full sensible set on. Master off clears them all.
/// Individual flags stay independently editable one level deeper.
public struct AlertCategoryFlags: Equatable, Sendable {
    public var diningOpen: Bool
    public var diningClosing: Bool
    public var campusHours: Bool
    public var libraryBusy: Bool

    public init(
        diningOpen: Bool,
        diningClosing: Bool,
        campusHours: Bool,
        libraryBusy: Bool
    ) {
        self.diningOpen = diningOpen
        self.diningClosing = diningClosing
        self.campusHours = campusHours
        self.libraryBusy = libraryBusy
    }

    public var masterOn: Bool {
        diningOpen || diningClosing || campusHours || libraryBusy
    }

    /// The full set currently exposed in Settings. No new categories.
    public static func applyingMaster(_ enabled: Bool) -> AlertCategoryFlags {
        AlertCategoryFlags(
            diningOpen: enabled,
            diningClosing: enabled,
            campusHours: enabled,
            libraryBusy: enabled
        )
    }
}
