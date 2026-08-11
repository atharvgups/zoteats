import Foundation

/// Period query for Dining Status hall-row deep links into Eat.
/// Open / opening-later rows carry the live meal (as a primary pill);
/// after-hours / unknown omit period so Eat stays on its empty state.
public enum DiningStatusDeepLink {
    public static func period(
        for state: HallOpenState,
        availablePeriods: [String]
    ) -> String? {
        let liveName: String
        switch state {
        case .open(let period, _), .openingLater(let period, _):
            liveName = period
        case .closedForToday, .unknown:
            return nil
        }

        let pills = DiningService.primaryPeriods(from: availablePeriods)
        return primaryPill(for: liveName, pills: pills)
    }

    private static func primaryPill(for liveName: String, pills: [String]) -> String? {
        let lower = liveName.lowercased()
        if lower.contains("brunch") || lower.contains("breakfast"), pills.contains("Breakfast") {
            return "Breakfast"
        }
        if lower.contains("lunch"), pills.contains("Lunch") { return "Lunch" }
        if lower.contains("dinner"), pills.contains("Dinner") { return "Dinner" }
        if pills.contains(liveName) { return liveName }
        return pills.first
    }
}
