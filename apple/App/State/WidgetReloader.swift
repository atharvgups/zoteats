import Foundation
import WidgetKit
import ZotEatsKit

/// Soft-reloads glanceable surfaces after in-app prefs change or background refresh.
enum WidgetReloader {
    static func reloadTodaysMenu() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.todaysMenu)
    }

    /// Refresh every Anteats widget after BG alert checks so Open Now / menus
    /// aren't stuck on a stale timeline until the next cadence fires.
    static func reloadAll() {
        for kind in WidgetTimelineKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
