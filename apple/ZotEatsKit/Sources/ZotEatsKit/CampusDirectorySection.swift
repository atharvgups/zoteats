import Foundation

/// Visual grouping for Campus like a dining-hall directory (Coffee / Food / Markets).
public enum CampusDirectorySection: String, CaseIterable, Sendable, Equatable {
    case coffee
    case food
    case markets

    public var title: String {
        switch self {
        case .coffee: return "Coffee"
        case .food: return "Food"
        case .markets: return "Markets"
        }
    }

    /// SF Symbol for the venue tile — cup, plate, basket.
    public var symbolName: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .markets: return "basket.fill"
        }
    }

    public static func grouping(forHubCategory category: String) -> CampusDirectorySection {
        if CampusTypeFilter.coffee.matches(category: category) { return .coffee }
        if CampusTypeFilter.markets.matches(category: category) { return .markets }
        return .food
    }
}
