import Foundation

/// Eat station lists: one card per dish, with air between — never a shared box.
public enum EatDishListLayout: Sendable {
    public static let cardSpacing: CGFloat = 10

    /// Unique among siblings in Eat’s LazyVStack (favorites / hits / stations
    /// can otherwise share a dish id and steal taps).
    public static func rowID(section: String, itemID: String) -> String {
        "\(section)|\(itemID)"
    }

    public static func rows(section: String, items: [MenuItem]) -> [EatDishRowRef] {
        items.map { EatDishRowRef(section: section, item: $0) }
    }
}

/// One dish row’s identity in a named Eat section.
public struct EatDishRowRef: Identifiable, Hashable, Sendable {
    public let id: String
    public let item: MenuItem

    public init(section: String, item: MenuItem) {
        self.id = EatDishListLayout.rowID(section: section, itemID: item.id)
        self.item = item
    }
}
