import Foundation

/// Which escape hatch to offer when Campus filters hide every spot.
public enum CampusListEmptyAction: Equatable, Sendable {
    /// Clear the selected category pill (optionally still in Open now).
    case clearCategory
    /// Turn off Open now so closed venues reappear.
    case showClosed
    /// Feed truly empty — no CTA.
    case none

    public static func resolve(hasCategoryFilter: Bool, openOnly: Bool) -> CampusListEmptyAction {
        if hasCategoryFilter { return .clearCategory }
        if openOnly { return .showClosed }
        return .none
    }
}
