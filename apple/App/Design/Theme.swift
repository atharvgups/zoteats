import SwiftUI

// Anteats design language — UCI identity with Ryo Lu / Notion restraint and
// a warm paper atmosphere (Ariv’s playground + Chloe’s calm depth, adapted
// for a campus food app). Content leads; chrome stays quiet; motion is soft.

extension Color {
    /// UCI primary blue (#0064A4).
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200).
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for gradients (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Soft ink for primary copy on warm paper (Ariv-adjacent; adapts in dark).
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor(red: 23 / 255, green: 19 / 255, blue: 16 / 255, alpha: 1)
    })

    /// Muted secondary text on paper.
    static let inkMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.62, alpha: 1)
            : UIColor(red: 97 / 255, green: 88 / 255, blue: 74 / 255, alpha: 1)
    })

    /// Warm paper page — gold-kissed cream in light, near-black in dark.
    static let screen = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 14 / 255, green: 14 / 255, blue: 15 / 255, alpha: 1)
        }
        // #FFF6E6 — soft UCI-gold wash (not flat system white).
        return UIColor(red: 255 / 255, green: 246 / 255, blue: 230 / 255, alpha: 1)
    })

    /// Card surface: slightly brighter paper in light; elevated charcoal in dark.
    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
        }
        // #FFFCF3
        return UIColor(red: 255 / 255, green: 252 / 255, blue: 243 / 255, alpha: 1)
    })

    /// Soft hairline — warm in light, cool in dark.
    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 230 / 255, green: 220 / 255, blue: 195 / 255, alpha: 1)
    })

    /// Quiet selected fill (Notion-style wash of brand blue).
    static let selectWash = Color.uciBlue.opacity(0.10)

    static let openGreen = Color(red: 52 / 255, green: 178 / 255, blue: 51 / 255)
    static let busyOrange = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let crowdedRed = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255)
}

enum ZotFont {
    /// Screen title — rounded for presence (Ryo / modern iOS editorial).
    static func hero(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
    /// One notch larger than footnote: pills are primary controls.
    static let pill = Font.system(.subheadline, design: .rounded).weight(.medium)
}

// MARK: - Motion (soft springs — presence, not bounce)

enum ZotMotion {
    static let select = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let soft = Animation.spring(response: 0.48, dampingFraction: 0.86)
    static let appear = Animation.spring(response: 0.55, dampingFraction: 0.88)
}

// MARK: - Radius tokens (one language of rounding everywhere)

/// Cards and sheets — slightly softer continuous corners.
let zotCardRadius: CGFloat = 18
/// Rows and tiles nested inside cards.
let zotInnerRadius: CGFloat = 12
/// Small chips and badges.
let zotChipRadius: CGFloat = 8

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            // Notion-quiet elevation — barely there.
            .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
    }
}

extension View {
    func zotCard() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Dietary tag colors

/// Soft desaturated tags that sit calmly on warm paper.
enum TagPalette {
    static let sage = Color(red: 68 / 255, green: 131 / 255, blue: 97 / 255)
    static let eucalyptus = Color(red: 89 / 255, green: 148 / 255, blue: 132 / 255)
    static let slate = Color(red: 84 / 255, green: 118 / 255, blue: 159 / 255)
    static let plum = Color(red: 132 / 255, green: 104 / 255, blue: 156 / 255)
    static let ochre = Color(red: 158 / 255, green: 124 / 255, blue: 76 / 255)
    static let clay = Color(red: 147 / 255, green: 110 / 255, blue: 90 / 255)
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
        case "No Dairy": terracotta
        case "Plant Forward", "Plant Powered": sage
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
