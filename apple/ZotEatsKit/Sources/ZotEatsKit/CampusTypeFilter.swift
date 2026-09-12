import Foundation

/// Primary Campus type filter — fewer chips than the old four-category bar.
/// Food Courts and Restaurants & Pubs share **Food**.
public enum CampusTypeFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case coffee
    case food
    case markets

    public var title: String {
        switch self {
        case .all: return "All"
        case .coffee: return "Coffee"
        case .food: return "Food"
        case .markets: return "Markets"
        }
    }

    /// Whether a place's hub category belongs under this filter.
    public func matches(category: String) -> Bool {
        switch self {
        case .all:
            return true
        case .coffee:
            return category == "Coffee & Cafés"
        case .food:
            return category == "Food Courts" || category == "Restaurants & Pubs"
        case .markets:
            return category == "Markets"
        }
    }

    /// Categories this filter covers (for empty-state scoped next-open).
    public var coveredCategories: [String] {
        switch self {
        case .all:
            return []
        case .coffee:
            return ["Coffee & Cafés"]
        case .food:
            return ["Food Courts", "Restaurants & Pubs"]
        case .markets:
            return ["Markets"]
        }
    }
}
