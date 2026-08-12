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
        now: Date = Date(),
        opensNextAtMinutes: Int? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextWeekday: String? = nil,
        opensNextPeriod: String? = nil
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
        case .awaitingMoreMeals:
            return Resolved(
                statusText: "More meals post later",
                countdownEnd: nil,
                countdownKind: nil
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
            if let open = opensNextAtMinutes,
               let offset = opensNextDayOffset,
               let weekday = opensNextWeekday,
               !weekday.isEmpty {
                let meal = opensNextPeriod ?? "Opens"
                return Resolved(
                    statusText: "\(meal) \(weekday)",
                    countdownEnd: UCITime.date(forMinutes: open, dayOffset: offset, now: now),
                    countdownKind: .opens
                )
            }
            return Resolved(statusText: "Closed for today", countdownEnd: nil, countdownKind: nil)
        case .unknown:
            // Ignore todayHours — echoing it beside unknown state reintroduces lies
            // (DiningLocationHoursLine parity).
            _ = todayHours
            return Resolved(
                statusText: "Hours unavailable",
                countdownEnd: nil,
                countdownKind: nil
            )
        }
    }
}
