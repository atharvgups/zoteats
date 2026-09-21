import Foundation

/// Short 3-across Eat hall status — one small hours line under the name:
/// "Open · until 8 PM" / "Closed · opens 7 AM" / Coming Soon.
public struct EatHallCardStatus: Sendable, Equatable {
    public let primary: String
    public let secondary: String?

    public init(primary: String, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    public var accessibilityLine: String {
        if let secondary, !secondary.isEmpty {
            return "\(primary), \(secondary)"
        }
        return primary
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
            return EatHallCardStatus(primary: OasisComingSoonCopy.cardStatus)
        }
        switch state {
        case .open(_, let closesAt):
            return EatHallCardStatus(primary: "Open · until \(compactClock(minutes: closesAt))")
        case .openingLater(_, let opensAt):
            return EatHallCardStatus(primary: "Closed · opens \(compactClock(minutes: opensAt))")
        case .awaitingMoreMeals:
            return EatHallCardStatus(primary: "More later")
        case .closedForToday:
            if let open = opensTomorrowAtMinutes {
                return EatHallCardStatus(primary: "Closed · opens \(compactClock(minutes: open))")
            }
            if let open = opensNextAtMinutes,
               let weekday = opensNextWeekday?.trimmingCharacters(in: .whitespacesAndNewlines),
               !weekday.isEmpty {
                let short = weekday.count <= 3 ? weekday : String(weekday.prefix(3))
                return EatHallCardStatus(primary: "Closed · \(short) \(compactClock(minutes: open))")
            }
            return EatHallCardStatus(primary: "Closed")
        case .unknown:
            return EatHallCardStatus(primary: "Not posted")
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
}
