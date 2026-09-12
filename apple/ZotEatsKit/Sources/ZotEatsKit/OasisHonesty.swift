import Foundation

/// Short Eat copy for The Oasis while Dining Hub has no live board.
/// Hub (uci.mydininghub.com/en/location/the-oasis-dining-hall): lunch + dinner,
/// no breakfast, no to-go, meal-plan members, Mon–Fri. Housing meal plans
/// start Sept 21, 2026. Never a paragraph, never a fake menu or occupancy.
public enum OasisComingSoonCopy: Sendable {
    /// Hall-card status — one meal-name slot.
    public static let cardStatus = "Coming Soon"
    /// Selected empty board — one short line, not Hub policy text.
    public static let selectedLine = "Opens Sept 21 · Lunch & Dinner"
}

/// Dining Hub listing for The Oasis. Peek `getLocations`; only `liveBoard`
/// means Hub marked `hasActiveMenus`. Recipes are scraped separately — a live
/// flag with an empty SKU map still stays Coming Soon (no invented menu).
public enum OasisHubListing: Equatable, Sendable {
    case notListed
    case comingSoon
    case liveBoard(urlKey: String)

    public static func resolve(
        _ rows: [(urlKey: String, hasActiveMenus: Bool)]
    ) -> OasisHubListing {
        guard let row = rows.first(where: { HallDirectory.isOasis($0.urlKey) }) else {
            return .notListed
        }
        if row.hasActiveMenus {
            return .liveBoard(urlKey: row.urlKey)
        }
        return .comingSoon
    }
}
