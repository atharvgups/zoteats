import Foundation
import WidgetKit
import ZotEatsKit

/// Soft-reloads glanceable surfaces after in-app prefs change or background refresh.
enum WidgetReloader {
    static func reloadTodaysMenu() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.todaysMenu)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.favoritesToday)
    }

    /// Wake Campus Open Now + Campus Next after Campus heart toggles so Home
    /// Screen order matches the in-app Favorites shelf without waiting on cadence.
    static func reloadCampusOpen() {
        for kind in WidgetTimelineKinds.campus {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    /// Wake Dining Status + Today's Menu + Favorites after Eat force-refreshes
    /// a dining board so Home/Lock glances match the newly posted Lunch/Dinner.
    static func reloadEatWidgets() {
        for kind in WidgetTimelineKinds.eat {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    /// Study / Quietest (+ Dining Status tip that embeds quietest).
    static func reloadStudyWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.quietestLibrary)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetTimelineKinds.diningStatus)
    }

    /// Refresh every Anteats widget after BG alert checks so Open Now / menus
    /// aren't stuck on a stale timeline until the next cadence fires.
    static func reloadAll() {
        for kind in WidgetTimelineKinds.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
