import Foundation

/// Honest empty copy for Campus menu sheets — never invent dishes.
public enum CampusMenuEmptyCopy {
    public enum Kind: Equatable, Sendable {
        /// Hub / brand never publishes a public menu here.
        case notPublished
        /// Venue usually posts, but today's board is empty.
        case notPosted
    }

    public static func kind(hasMenuFlag: Bool, category: String) -> Kind {
        // Only Hub’s hasActiveMenus flag means “usually posts.” Food courts /
        // pubs without that flag often never publish — don’t claim they do.
        _ = category
        if hasMenuFlag { return .notPosted }
        return .notPublished
    }

    public static func title(_ kind: Kind) -> String {
        switch kind {
        case .notPublished: return "No published menu"
        case .notPosted: return "Menu not posted"
        }
    }

    public static func message(kind: Kind, placeName: String) -> String {
        switch kind {
        case .notPublished:
            return "\(placeName) doesn't post its menu here — check the brand's own app for ordering."
        case .notPosted:
            return "\(placeName) usually posts a menu here, but nothing is listed for today yet."
        }
    }
}
