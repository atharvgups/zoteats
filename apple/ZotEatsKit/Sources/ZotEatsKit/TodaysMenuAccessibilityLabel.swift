import Foundation

/// VoiceOver labels for Today's Menu — empty states must match the honest
/// on-screen copy (filters / after-hours / not posted), not `"Hall Period: "`.
public enum TodaysMenuAccessibilityLabel {
    public enum Surface: Equatable, Sendable {
        case glance
        case home

        var emptyCopySurface: TodaysMenuEmptyCopy.Surface {
            switch self {
            case .glance: return .glance
            case .home: return .home
            }
        }
    }

    public static func label(
        hallName: String,
        period: String,
        dishes: [String],
        filtersEmptiedMenu: Bool,
        dishLimit: Int,
        surface: Surface,
        opensTomorrowPeriod: String? = nil,
        opensTomorrowAtMinutes: Int? = nil,
        awaitingMoreMeals: Bool = false,
        opensNextPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        isAfterHours: Bool = false
    ) -> String {
        let listed = Array(dishes.prefix(max(0, dishLimit)))
        if !listed.isEmpty {
            let head = period.isEmpty ? hallName : "\(hallName) \(period)"
            return "\(head): \(listed.joined(separator: ", "))"
        }

        let reason = TodaysMenuEmptyCopy.reason(
            periodIsEmpty: period.isEmpty,
            filtersEmptiedMenu: filtersEmptiedMenu,
            opensTomorrowPeriod: opensTomorrowPeriod,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            surface: surface.emptyCopySurface,
            awaitingMoreMeals: awaitingMoreMeals,
            opensNextPeriod: opensNextPeriod,
            opensNextAtMinutes: opensNextAtMinutes,
            opensNextWeekday: opensNextWeekday,
            isAfterHours: isAfterHours
        )

        let head = period.isEmpty ? hallName : "\(hallName) \(period)"
        return "\(head). \(reason)"
    }
}
