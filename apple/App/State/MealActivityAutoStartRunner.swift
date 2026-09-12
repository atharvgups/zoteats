import Foundation
import ActivityKit
import ZotEatsKit

/// App-level Live Activity auto-start — runs on foreground / BG so Settings
/// “Auto meal countdown” works when Eat is unloaded (Campus / Study).
@MainActor
enum MealActivityAutoStartRunner {
    static func run(service: DiningService = DiningService()) async {
        let manager = MealActivityManager()
        manager.syncFromSystem()
        let locations = await service.locations()
        // Refresh baked post-close even when already tracking (board grew).
        manager.refreshPostCloseIfNeeded(locations: locations)
        guard MealActivityManager.autoStartEnabled else { return }
        guard let pick = MealActivityAutoStart.pick(
            locations: locations,
            nowMinutes: UCITime.nowMinutes(),
            alreadyTracking: manager.trackedKey != nil,
            autoEnabled: true
        ) else { return }

        let postClose = MealActivityPostClose.destination(
            currentPeriodEndMinutes: pick.endMinutes,
            timedPeriods: pick.timedPeriods,
            opensTomorrowPeriod: pick.opensTomorrowPeriod,
            opensNextPeriod: pick.opensNextPeriod,
            opensNextDayOffset: pick.opensNextDayOffset,
            opensNextDateISO: pick.opensNextDateISO
        )
        _ = await manager.autoStartIfNeeded(
            hallName: pick.hallName,
            hallID: pick.hallID,
            period: pick.livePeriodName,
            startMinutes: pick.startMinutes,
            endMinutes: pick.endMinutes,
            postClosePeriod: postClose.period,
            postCloseDate: postClose.date,
            opensTomorrowPeriod: MealActivityPostClose.contentOpensTomorrowPeriod(
                postClose: postClose,
                hallOpensTomorrowPeriod: pick.opensTomorrowPeriod
            )
        )
    }
}
