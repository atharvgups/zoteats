import Foundation

/// WidgetKit `kind` strings for every Anteats glance — kept in the Kit so
/// reload coverage stays unit-testable on Linux without importing WidgetKit.
public enum WidgetTimelineKinds {
    public static let diningStatus = "ZotEatsDiningStatus"
    public static let todaysMenu = "ZotEatsTodaysMenu"
    public static let campusOpen = "ZotEatsCampusOpen"
    public static let arcStatus = "ZotEatsArcStatus"
    public static let quietestLibrary = "ZotEatsQuietestLibrary"

    /// Every Home Screen / Lock Screen / StandBy timeline the app ships.
    public static let all: [String] = [
        diningStatus,
        todaysMenu,
        campusOpen,
        arcStatus,
        quietestLibrary,
    ]
}
