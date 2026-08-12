import Foundation

/// VoiceOver labels for Today's Menu — empty states must match the honest
/// on-screen copy (filters / after-hours / not posted), not `"Hall Period: "`.
public enum TodaysMenuAccessibilityLabel {
    public enum Surface: Equatable, Sendable {
        case glance
        case home
    }

    public static func label(
        hallName: String,
        period: String,
        dishes: [String],
        filtersEmptiedMenu: Bool,
        dishLimit: Int,
        surface: Surface
    ) -> String {
        let listed = Array(dishes.prefix(max(0, dishLimit)))
        if !listed.isEmpty {
            let head = period.isEmpty ? hallName : "\(hallName) \(period)"
            return "\(head): \(listed.joined(separator: ", "))"
        }

        let reason: String
        if filtersEmptiedMenu {
            reason = surface == .glance
                ? "Nothing matches Eat Filters"
                : "Nothing matches your Eat Filters"
        } else if period.isEmpty {
            reason = surface == .glance
                ? "See you at breakfast"
                : "Dinner's done — breakfast posts overnight"
        } else {
            reason = surface == .glance
                ? "Menu not posted yet"
                : "No menu posted right now — check back at the next meal"
        }

        let head = period.isEmpty ? hallName : "\(hallName) \(period)"
        return "\(head). \(reason)"
    }
}
