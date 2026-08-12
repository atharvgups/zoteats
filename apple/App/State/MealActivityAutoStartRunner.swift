import Foundation
import ActivityKit
import ZotEatsKit

/// App-level Live Activity auto-start — runs on foreground / BG so Settings
/// “Auto meal countdown” works when Eat is unloaded (Campus / Gym / Study).
@MainActor
enum MealActivityAutoStartRunner {
    static func run(service: DiningService = DiningService()) async {
        guard MealActivityManager.autoStartEnabled else { return }
        let manager = MealActivityManager()
        manager.syncFromSystem()
        let locations = await service.locations()
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
        manager.autoStartIfNeeded(
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
