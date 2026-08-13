import Foundation
import WidgetKit
import ZotEatsKit

/// Soft-reloads glanceable surfaces after in-app prefs change or background refresh.
enum WidgetReloader {
    static func reloadTodaysMenu() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.todaysMenu)
    }

    /// Wake Campus Open Now after Campus heart toggles so Home Screen order
    /// matches the in-app Favorites shelf without waiting on WidgetKit cadence.
    static func reloadCampusOpen() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.campusOpen)
    }

    /// Wake Dining Status + Today's Menu after Eat force-refreshes a dining board
    /// so Home/Lock glances match the newly posted Lunch/Dinner without waiting
    /// for the next WidgetKit cadence.
    static func reloadEatWidgets() {
        for kind in WidgetTimelineKinds.eat {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    /// Refresh every Anteats widget after BG alert checks so Open Now / menus
    /// aren't stuck on a stale timeline until the next cadence fires.
    static func reloadAll() {
        for kind in WidgetTimelineKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
