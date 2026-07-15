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
    /// One notch larger than footnote: pills are primary controls, and the
    /// extra size improves tap targets.
    static let pill = Font.subheadline.weight(.medium)
}

// MARK: - Radius tokens (one language of rounding everywhere)

/// Cards and sheets.
let zotCardRadius: CGFloat = 16
/// Rows and tiles nested inside cards.
let zotInnerRadius: CGFloat = 10
/// Small chips and badges.
let zotChipRadius: CGFloat = 7

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

/// Notion-style tag palette: muted, desaturated hues that read calm on both
/// light and dark surfaces (the chip renders them at low-opacity fill + full text).
enum TagPalette {
    /// Muted moss green.
    static let sage = Color(red: 68 / 255, green: 131 / 255, blue: 97 / 255)
    /// Soft eucalyptus.
    static let eucalyptus = Color(red: 89 / 255, green: 148 / 255, blue: 132 / 255)
    /// Dusty slate blue.
    static let slate = Color(red: 84 / 255, green: 118 / 255, blue: 159 / 255)
    /// Muted plum.
    static let plum = Color(red: 132 / 255, green: 104 / 255, blue: 156 / 255)
    /// Warm sand/ochre.
    static let ochre = Color(red: 158 / 255, green: 124 / 255, blue: 76 / 255)
    /// Soft clay brown.
    static let clay = Color(red: 147 / 255, green: 110 / 255, blue: 90 / 255)
    /// Dusty terracotta for allergens — cautionary without shouting.
    static let terracotta = Color(red: 178 / 255, green: 106 / 255, blue: 87 / 255)

    static func dietColor(_ tag: String) -> Color {
        switch tag {
        case "Vegan": sage
        case "Vegetarian": eucalyptus
        case "Halal": slate
        case "Kosher": plum
        case "Gluten-Free": ochre
        case "Organic": sage
        case "Locally Grown": clay
        default: .secondary
        }
    }

    static let allergenColor: Color = terracotta
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
