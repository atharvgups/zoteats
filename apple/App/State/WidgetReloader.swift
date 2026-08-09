import Foundation
import WidgetKit

/// Soft-reloads glanceable surfaces after in-app prefs change.
enum WidgetReloader {
    static let todaysMenuKind = "ZotEatsTodaysMenu"

    static func reloadTodaysMenu() {
        WidgetCenter.shared.reloadTimelines(ofKind: todaysMenuKind)
    }
}
