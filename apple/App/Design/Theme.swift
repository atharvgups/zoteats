import SwiftUI

// ZotEats design language — UCI identity, warm and food-forward.
// Inspired by the best campus dining apps (UCLA's Nom, PeterPlate) and
// modern iOS food apps: rounded type, soft cards, confident color.

// Notion-inspired restraint: plain background, hairline-bordered flat cards,
// editorial type, color used sparingly as accent — content leads.

extension Color {
    /// UCI primary blue (#0064A4).
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200).
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for gradients (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Card surface: same as the page in light (borders differentiate), elevated in dark.
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    /// Page background: plain, Notion-white (near-black in dark mode).
    static let screen = Color(uiColor: .systemBackground)
    /// Hairline card border.
    static let cardBorder = Color.primary.opacity(0.09)

    static let openGreen = Color(red: 52 / 255, green: 178 / 255, blue: 51 / 255)
    static let busyOrange = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let crowdedRed = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255)
}

enum ZotFont {
    /// Screen title, e.g. "Dining" — bold but plain, editorial.
    static func hero(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold)
    }

    static let cardTitle = Font.headline.weight(.semibold)
    static let sectionTitle = Font.subheadline.weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
    static let pill = Font.footnote.weight(.medium)
}

// MARK: - Card

let zotCardRadius: CGFloat = 12

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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
