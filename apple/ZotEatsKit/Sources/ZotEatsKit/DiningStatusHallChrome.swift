import Foundation

/// Status line + countdown chrome for Dining Status hall rows.
/// After hours with a known tomorrow open says "Breakfast tomorrow" (not bare
/// "Breakfast") so the glance doesn't read like a same-day meal; the live
/// opens timer still carries the clock.
public enum DiningStatusHallChrome {
    public enum CountdownKind: Equatable, Sendable {
        case opens
        case closes
    }

    public struct Resolved: Equatable, Sendable {
        public let statusText: String
        public let countdownEnd: Date?
        public let countdownKind: CountdownKind?

        public init(
            statusText: String,
            countdownEnd: Date?,
            countdownKind: CountdownKind?
        ) {
            self.statusText = statusText
            self.countdownEnd = countdownEnd
            self.countdownKind = countdownKind
        }
    }

    public static func resolve(
        state: HallOpenState,
        todayHours: String?,
        opensTomorrowAtMinutes: Int?,
        opensTomorrowPeriod: String?,
        nowMinutes: Int,
        now: Date = Date()
    ) -> Resolved {
        switch state {
        case .open(let period, let closesAt):
            return Resolved(
                statusText: period,
                countdownEnd: UCITime.date(forMinutes: closesAt, nowMinutes: nowMinutes, now: now),
                countdownKind: .closes
            )
        case .openingLater(let period, let opensAt):
            return Resolved(
                statusText: period,
                countdownEnd: UCITime.date(forMinutes: opensAt, nowMinutes: nowMinutes, now: now),
                countdownKind: .opens
            )
        case .closedForToday:
            if let open = opensTomorrowAtMinutes {
                let meal = opensTomorrowPeriod ?? "Opens"
                return Resolved(
                    statusText: "\(meal) tomorrow",
                    countdownEnd: UCITime.date(forMinutes: open, nowMinutes: nowMinutes, now: now),
                    countdownKind: .opens
                )
            }
            return Resolved(statusText: "Closed for today", countdownEnd: nil, countdownKind: nil)
        case .unknown:
            return Resolved(
                statusText: todayHours ?? "Hours unavailable",
                countdownEnd: nil,
                countdownKind: nil
            )
        }
    }
}
