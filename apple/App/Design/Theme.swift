import SwiftUI

// ZotEats design language — UCI identity, warm and food-forward.
// Inspired by the best campus dining apps (UCLA's Nom, PeterPlate) and
// modern iOS food apps: rounded type, soft cards, confident color.

extension Color {
    /// UCI primary blue (#0064A4).
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200).
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for gradients (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Adaptive card surface.
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    /// Adaptive grouped screen background.
    static let screen = Color(uiColor: .systemGroupedBackground)

    static let openGreen = Color(red: 52 / 255, green: 178 / 255, blue: 51 / 255)
    static let busyOrange = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let crowdedRed = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255)
}

enum ZotFont {
    /// Big friendly screen title, e.g. "Dining".
    static func hero(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let cardTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let pill = Font.system(.subheadline, design: .rounded).weight(.medium)
}

// MARK: - Card

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func zotCard() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Dietary tag colors

enum TagPalette {
    /// Diet tags read positive (greens/teals); allergens read cautionary (warm).
    static func dietColor(_ tag: String) -> Color {
        switch tag {
        case "Vegan": .green
        case "Vegetarian": .mint
        case "Halal": .teal
        case "Kosher": .indigo
        case "Gluten-Free": .cyan
        case "Organic": .green
        case "Locally Grown": .brown
        default: .secondary
        }
    }

    static let allergenColor: Color = .orange
}

// MARK: - Busyness level presentation

import ZotEatsKit

extension BusynessLevel {
    var label: String {
        switch self {
        case .notBusy: "Not busy"
        case .busy: "Busy"
        case .veryBusy: "Very busy"
        case .unknown: "No data"
        }
    }

    var color: Color {
        switch self {
        case .notBusy: .openGreen
        case .busy: .busyOrange
        case .veryBusy: .crowdedRed
        case .unknown: .secondary
        }
    }
}
