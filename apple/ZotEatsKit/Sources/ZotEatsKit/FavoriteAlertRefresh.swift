import Foundation

/// When to aim the shared BGAppRefresh that powers Favorite Alerts (and the
/// Menu Drop / Opening Alerts / widget reload pipeline hooked to the same id).
///
/// iOS only grants one pending request per identifier — after a morning fire
/// we must aim again before lunch, dinner, and evening menu publishes, or
/// Dinner hearts / overnight Menu Drops only land on foreground.
public enum FavoriteAlertRefresh {
    /// Pacific minutes: breakfast lead, pre-lunch, pre-dinner, evening menu drop.
    public static let aimMinutes = [
        6 * 60 + 45,
        11 * 60 + 15,
        16 * 60 + 15,
        20 * 60,
    ]

    /// Skip an aim that is already inside this lead window (iOS delay + fetch).
    public static let minimumLead: TimeInterval = 30 * 60

    /// BGAppRefresh floor — matches historical `FavoriteAlerts.scheduleNextRefresh`.
    public static let minimumInterval: TimeInterval = 60 * 60

    /// Soonest same-day aim still outside `minimumLead`, else tomorrow breakfast.
    public static func preferredBeginDate(
        now: Date = Date(),
        minimumLead: TimeInterval = minimumLead
    ) -> Date {
        let nowMinutes = UCITime.nowMinutes(now: now)
        let threshold = now.addingTimeInterval(minimumLead)
        for minutes in aimMinutes where minutes >= nowMinutes {
            let aim = UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
            if aim > threshold { return aim }
        }
        // All today's aims are too soon or already past — tomorrow breakfast.
        return UCITime.date(
            forMinutes: aimMinutes[0],
            nowMinutes: nowMinutes,
            now: now
        )
    }

    /// `preferredBeginDate` floored at `now + minimumInterval` for BG submit.
    public static func earliestBeginDate(
        now: Date = Date(),
        minimumLead: TimeInterval = minimumLead,
        minimumInterval: TimeInterval = minimumInterval
    ) -> Date {
        max(
            preferredBeginDate(now: now, minimumLead: minimumLead),
            now.addingTimeInterval(minimumInterval)
        )
    }
}
