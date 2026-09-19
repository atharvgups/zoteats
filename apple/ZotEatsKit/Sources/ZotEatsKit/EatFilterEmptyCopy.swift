import Foundation

/// Honest empty copy when a loaded menu is wiped by search and/or Eat Filters.
/// Eat uses all three branches; Campus menu sheets call `hasSearch: false` (filters only).
public enum EatFilterEmptyCopy {
    public enum Action: Equatable, Sendable {
        case clearSearch
        case clearFilters
        case clearBoth
    }

    public struct Copy: Equatable, Sendable {
        public let title: String
        public let message: String
        public let actionTitle: String
        public let action: Action

        public init(title: String, message: String, actionTitle: String, action: Action) {
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }
    }

    /// Returns nil when nothing is filtering the board (caller shows "no menu posted").
    public static func resolve(hasSearch: Bool, hasMenuFilters: Bool) -> Copy? {
        switch (hasSearch, hasMenuFilters) {
        case (true, false):
            return Copy(
                title: "Nothing matches that search",
                message: "The anteaters got to it first. Try a different dish name.",
                actionTitle: "Clear search",
                action: .clearSearch
            )
        case (false, true):
            return Copy(
                title: "Nothing matches those filters",
                message: "The anteaters got to it first. Clear your Eat Filters to see the full board.",
                actionTitle: "Clear filters",
                action: .clearFilters
            )
        case (true, true):
            return Copy(
                title: "Nothing matches",
                message: "No dishes match that search with your Eat Filters on. Clear search, filters, or both.",
                actionTitle: "Clear both",
                action: .clearBoth
            )
        case (false, false):
            return nil
        }
    }
}
