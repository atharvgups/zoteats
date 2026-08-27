import Foundation

/// WidgetKit `kind` strings for every Anteats glance — kept in the Kit so
/// reload coverage stays unit-testable on Linux without importing WidgetKit.
public enum WidgetTimelineKinds {
    public static let diningStatus = "ZotEatsDiningStatus"
    public static let todaysMenu = "ZotEatsTodaysMenu"
    public static let favoritesToday = "ZotEatsFavoritesToday"
    public static let campusOpen = "ZotEatsCampusOpen"
    /// Removed from the shipping gallery with the Gym cut — kept for purge/reload.
    public static let campusNext = "ZotEatsCampusNext"
    /// Parked with the ARC Gym widget until live sensors exist — not in `all`.
    public static let arcStatus = "ZotEatsArcStatus"
    public static let quietestLibrary = "ZotEatsQuietestLibrary"
    public static let campusStudy = "ZotEatsCampusStudy"

    /// Every Home Screen / Lock Screen / StandBy timeline the app ships.
    /// ARC Gym / Campus Next are intentionally omitted from the gallery.
    public static let all: [String] = [
        diningStatus,
        todaysMenu,
        favoritesToday,
        campusOpen,
        campusStudy,
        quietestLibrary,
    ]

    /// Eat-facing glances that should wake when dining boards force-refresh
    /// (pull-to-refresh / Lunch·Dinner publish probes) — not Campus/Study.
    public static let eat: [String] = [
        diningStatus,
        todaysMenu,
        favoritesToday,
    ]

    /// Campus glances that should wake when Campus hearts change.
    public static let campus: [String] = [
        campusOpen,
        campusStudy,
    ]
}
