import Foundation

/// When to aim the shared BGAppRefresh that powers Favorite Alerts (and the
/// Menu Drop / Opening Alerts / widget reload / Live Activity auto-start
/// pipeline hooked to the same id).
///
/// iOS only grants one pending request per identifier — after a morning fire
/// we must aim again before lunch, dinner, evening menu publishes, meal open
/// times, and meal wrap-up (T−45) windows, or Dinner hearts / Island auto-start
/// only land on Eat-tab foreground.
public enum FavoriteAlertRefresh {
    /// Pacific minutes: breakfast lead, then Lunch / Dinner / evening menu-drop
    /// probes shared with `DiningBoardPublish.publishProbeMinutes`. Live meal
    /// opens (and wrap-ups) arrive via `extraAimMinutes` so Brunch / hall-
    /// specific Dinner beat these walls.
    public static let aimMinutes = [6 * 60 + 45] + DiningBoardPublish.publishProbeMinutes

    /// Skip a fixed aim that is already inside this lead window (iOS delay + fetch).
    public static let minimumLead: TimeInterval = 30 * 60

    /// Live meal-open and wrap-up (meal end − 45) aims use a short lead so the
    /// open / T−45 minute isn't skipped.
    public static let wrapUpMinimumLead: TimeInterval = 2 * 60

    /// BGAppRefresh floor for fixed aims — matches historical scheduleNextRefresh.
    public static let minimumInterval: TimeInterval = 60 * 60

    /// Soonest fixed or live (open / wrap-up) aim still outside its lead, else
    /// tomorrow breakfast.
    public static func preferredBeginDate(
        now: Date = Date(),
        minimumLead: TimeInterval = minimumLead,
        wrapUpMinimumLead: TimeInterval = wrapUpMinimumLead,
        extraAimMinutes: [Int] = []
    ) -> Date {
        let nowMinutes = UCITime.nowMinutes(now: now)
        var candidates: [Date] = []

        let fixedThreshold = now.addingTimeInterval(minimumLead)
        for minutes in aimMinutes where minutes >= nowMinutes {
            let aim = UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            if aim > fixedThreshold { candidates.append(aim) }
        }

        let liveThreshold = now.addingTimeInterval(wrapUpMinimumLead)
        for minutes in Set(extraAimMinutes) where minutes >= nowMinutes {
            let aim = UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            if aim > liveThreshold { candidates.append(aim) }
        }

        if let soonest = candidates.min() { return soonest }
        return UCITime.date(
            forMinutes: aimMinutes[0],
            nowMinutes: nowMinutes,
            now: now
        )
    }

    /// Preferred begin floored at `now + minimumInterval`, except live open /
    /// wrap-up aims and `allowImmediate` (already inside a T−45 window) which
    /// only need ~1m.
    public static func earliestBeginDate(
        now: Date = Date(),
        minimumLead: TimeInterval = minimumLead,
        minimumInterval: TimeInterval = minimumInterval,
        extraAimMinutes: [Int] = [],
        allowImmediate: Bool = false
    ) -> Date {
        if allowImmediate {
            return now.addingTimeInterval(60)
        }
        let preferred = preferredBeginDate(
            now: now,
            minimumLead: minimumLead,
            extraAimMinutes: extraAimMinutes
        )
        let nowMinutes = UCITime.nowMinutes(now: now)
        let isLiveAim = extraAimMinutes.contains { minutes in
            guard minutes >= nowMinutes else { return false }
            let aim = UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            return abs(aim.timeIntervalSince(preferred)) < 1
        }
        if isLiveAim {
            return max(preferred, now.addingTimeInterval(60))
        }
        return max(preferred, now.addingTimeInterval(minimumInterval))
    }
}
