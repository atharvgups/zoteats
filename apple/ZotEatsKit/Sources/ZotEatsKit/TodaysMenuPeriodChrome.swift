import Foundation

/// Countdown chrome for Today's Menu period pill — closes while serving,
/// opens between meals (Dining Status parity so StandBy doesn't read as live).
public enum TodaysMenuPeriodChrome {
    public enum Kind: Equatable, Sendable {
        case closes
        case opens
    }

    public struct Resolved: Equatable, Sendable {
        public let countdownEnd: Date?
        public let kind: Kind?

        public init(countdownEnd: Date?, kind: Kind?) {
            self.countdownEnd = countdownEnd
            self.kind = kind
        }
    }

    public static func resolve(
        endsAtMinutes: Int?,
        upcomingStartMinutes: Int?,
        nowMinutes: Int,
        now: Date = Date()
    ) -> Resolved {
        if let end = endsAtMinutes {
            return Resolved(
                countdownEnd: UCITime.date(forMinutes: end, nowMinutes: nowMinutes, now: now),
                kind: .closes
            )
        }
        if let start = upcomingStartMinutes {
            return Resolved(
                countdownEnd: UCITime.date(forMinutes: start, nowMinutes: nowMinutes, now: now),
                kind: .opens
            )
        }
        return Resolved(countdownEnd: nil, kind: nil)
    }
}
