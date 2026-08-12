import Foundation

/// Detects a still-incomplete dining board — Lunch/Dinner often publish
/// after Breakfast ends. Until the evening menu-drop aim, don't treat
/// "all published windows ended" as closed-for-today / jump to tomorrow.
public enum DiningBoardPublish {
    /// Matches Favorite Alerts' evening menu-drop slot (8:00 PM Irvine).
    public static let eveningConfidenceMinutes = 20 * 60

    /// Approximate Lunch / Dinner / evening menu-drop publishes — shared with
    /// `FavoriteAlertRefresh.aimMinutes` so widgets + Eat wake when boards grow.
    /// 10:30 / 10:50 bracket a typical 11:00 Lunch; 15:30 / 16:15 bracket Dinner
    /// so Opening Alerts can re-arm after publish and before open.
    public static let publishProbeMinutes = [
        10 * 60 + 30,
        10 * 60 + 50,
        11 * 60 + 15,
        15 * 60 + 30,
        16 * 60 + 15,
        eveningConfidenceMinutes,
    ]

    /// True when every timed window has ended, Dinner isn't on the board yet,
    /// and it's still before evening confidence — more meals may still drop.
    public static func awaitingLaterMeals(
        periods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> Bool {
        guard nowMinutes < eveningConfidenceMinutes else { return false }
        let timed = periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }
        guard !timed.isEmpty else { return false }
        guard timed.allSatisfy({ ($0.endMinutes ?? Int.min) <= nowMinutes }) else {
            return false
        }
        let hasDinner = timed.contains {
            MealPeriodPill.canonical($0.name) == "Dinner"
        }
        return !hasDinner
    }

    /// Future publish-probe minutes still ahead of `nowMinutes`.
    public static func upcomingPublishProbeMinutes(nowMinutes: Int) -> [Int] {
        guard nowMinutes < eveningConfidenceMinutes else { return [] }
        return publishProbeMinutes.filter { $0 > nowMinutes }
    }

    /// Future publish-probe wall clocks while still before evening confidence.
    public static func futurePublishProbeDates(
        nowMinutes: Int,
        now: Date = Date()
    ) -> [Date] {
        upcomingPublishProbeMinutes(nowMinutes: nowMinutes).map { minutes in
            UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now)
        }
    }
}
