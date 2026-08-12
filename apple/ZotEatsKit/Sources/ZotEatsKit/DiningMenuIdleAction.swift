import Foundation

/// Whether Eat should keep showing menu skeletons or an honest empty state.
/// Halls with no B/L/D periods (or a failed period selection) never leave
/// `.idle`, which previously spun placeholders forever.
public enum DiningMenuIdleAction: Equatable, Sendable {
    case loading
    case emptyNoMenu

    public static func resolve(
        locationsLoaded: Bool,
        availablePeriods: [String]?,
        selectedPeriod: String?,
        browseDayPeriodsPending: Bool = false
    ) -> DiningMenuIdleAction {
        guard locationsLoaded else { return .loading }
        // Future-day board still fetching that day's periods — keep skeletons.
        if browseDayPeriodsPending { return .loading }
        let periods = availablePeriods ?? []
        let primary = DiningService.primaryPeriods(from: periods)
        if periods.isEmpty || primary.isEmpty || selectedPeriod == nil {
            return .emptyNoMenu
        }
        return .loading
    }
}

/// Why Eat's `.emptyNoMenu` idle is empty — so copy matches hall chrome / widgets
/// (partial boards await later meals; after hours jump to next open).
public enum DiningMenuIdleEmptyKind: Equatable, Sendable {
    case awaitingMoreMeals
    case afterHours
    case noMenuPosted

    public static func resolve(
        browsingToday: Bool,
        openState: HallOpenState?
    ) -> DiningMenuIdleEmptyKind {
        guard browsingToday, let openState else { return .noMenuPosted }
        switch openState {
        case .awaitingMoreMeals:
            return .awaitingMoreMeals
        case .closedForToday:
            return .afterHours
        case .open, .openingLater, .unknown:
            return .noMenuPosted
        }
    }
}
