import Foundation

/// Short 3-across Eat hall status — one small hours line under the name:
/// "until 8 PM" (open / green) / "opens 7 AM" (closed / muted) / Coming Soon.
public enum EatHallCardTone: String, Sendable, Equatable {
    /// Serving now — green hours copy.
    case open
    /// Closed, coming soon, or unknown — muted grey hours copy.
    case muted
}

public struct EatHallCardStatus: Sendable, Equatable {
    public let primary: String
    public let secondary: String?
    public let tone: EatHallCardTone
    public let accessibilityLine: String

    public init(
        primary: String,
        secondary: String? = nil,
        tone: EatHallCardTone = .muted,
        accessibilityLine: String? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.tone = tone
        if let accessibilityLine, !accessibilityLine.isEmpty {
            self.accessibilityLine = accessibilityLine
        } else if let secondary, !secondary.isEmpty {
            self.accessibilityLine = "\(primary), \(secondary)"
        } else {
            self.accessibilityLine = primary
        }
    }
}

public enum EatHallCardChrome: Sendable {
    /// Drop ":00" so hall tiles can say "8 PM" instead of "8:00 PM".
    public static func compactClock(minutes: Int) -> String {
        UCITime.format(minutes: minutes % (24 * 60))
            .replacingOccurrences(of: ":00 ", with: " ")
    }

    public static func status(
        comingSoon: Bool,
        state: HallOpenState,
        opensTomorrowAtMinutes: Int? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        opensTomorrowPeriod _: String? = nil,
        opensNextPeriod _: String? = nil
    ) -> EatHallCardStatus {
        if comingSoon {
            return EatHallCardStatus(
                primary: OasisComingSoonCopy.cardStatus,
                tone: .muted
            )
        }
        switch state {
        case .open(_, let closesAt):
            let clock = compactClock(minutes: closesAt)
            return EatHallCardStatus(
                primary: "until \(clock)",
                tone: .open,
                accessibilityLine: "Open, until \(clock)"
            )
        case .openingLater(_, let opensAt):
            return closedOpens(compactClock(minutes: opensAt))
        case .awaitingMoreMeals:
            return EatHallCardStatus(primary: "More later", tone: .muted)
        case .closedForToday:
            if let open = opensTomorrowAtMinutes {
                return closedOpens(compactClock(minutes: open))
            }
            if let open = opensNextAtMinutes,
               let weekday = opensNextWeekday?.trimmingCharacters(in: .whitespacesAndNewlines),
               !weekday.isEmpty {
                let short = weekday.count <= 3 ? weekday : String(weekday.prefix(3))
                let clock = compactClock(minutes: open)
                return EatHallCardStatus(
                    primary: "opens \(short) \(clock)",
                    tone: .muted,
                    accessibilityLine: "Closed, opens \(short) \(clock)"
                )
            }
            return EatHallCardStatus(
                primary: "Closed",
                tone: .muted,
                accessibilityLine: "Closed"
            )
        case .unknown:
            return EatHallCardStatus(primary: "Not posted", tone: .muted)
        }
    }

    public static func statusText(
        comingSoon: Bool,
        state: HallOpenState,
        opensTomorrowAtMinutes: Int? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        opensTomorrowPeriod: String? = nil,
        opensNextPeriod: String? = nil
    ) -> String {
        status(
            comingSoon: comingSoon,
            state: state,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            opensNextAtMinutes: opensNextAtMinutes,
            opensNextWeekday: opensNextWeekday,
            opensTomorrowPeriod: opensTomorrowPeriod,
            opensNextPeriod: opensNextPeriod
        ).accessibilityLine
    }

    private static func closedOpens(_ clock: String) -> EatHallCardStatus {
        EatHallCardStatus(
            primary: "opens \(clock)",
            tone: .muted,
            accessibilityLine: "Closed, opens \(clock)"
        )
    }
}
