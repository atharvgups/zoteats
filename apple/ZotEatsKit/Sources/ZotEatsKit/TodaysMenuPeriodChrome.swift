import Foundation

/// Countdown chrome for Today's Menu period pill — closes while serving,
/// opens between meals (Dining Status parity so StandBy doesn't read as live).
/// Partial boards awaiting later meals keep last-posted dishes but must not
/// look like a live open window — Status "More meals post later" parity.
public enum TodaysMenuPeriodChrome {
    public enum Kind: Equatable, Sendable {
        case closes
        case opens
        case awaitingMoreMeals
    }

    public struct Resolved: Equatable, Sendable {
        public let countdownEnd: Date?
        public let kind: Kind?

        public init(countdownEnd: Date?, kind: Kind?) {
            self.countdownEnd = countdownEnd
            self.kind = kind
        }
    }

    /// Status / Eat hall-card glance string for partial boards.
    public static let awaitingCaption = "More meals post later"

    /// Compact capsule / Lock Screen companion beside the last posted meal.
    public static let awaitingCaptionCompact = "more later"

    public static func resolve(
        endsAtMinutes: Int?,
        upcomingStartMinutes: Int?,
        nowMinutes: Int,
        now: Date = Date(),
        awaitingMoreMeals: Bool = false
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
        if awaitingMoreMeals {
            return Resolved(countdownEnd: nil, kind: .awaitingMoreMeals)
        }
        return Resolved(countdownEnd: nil, kind: nil)
    }
}
