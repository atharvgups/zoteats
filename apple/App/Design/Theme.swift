import SwiftUI

// Anteats design language — warm analog parchment (Tolan-adjacent) with UCI
// gold as a quiet accent. Chrome stays charcoal; type is one grotesque family.
// Instrument Sans (SIL OFL) stands in for Tolan’s GT America, which we can’t
// ship without a commercial license.

extension Color {
    /// UCI primary blue (#0064A4) — kept for the cheer easter egg, not chrome.
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200).
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for the cheer gradient (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Charcoal ink on parchment; parchment ink in dark.
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 1)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 1)
    })

    /// Secondary copy — same ink, quieter.
    static let inkMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 0.58)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 0.52)
    })

    /// Page canvas — Tolan parchment #F4F2E7 / warm charcoal in dark.
    static let screen = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 28 / 255, green: 28 / 255, blue: 26 / 255, alpha: 1)
        }
        return UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 1)
    })

    /// Card surface, a hair off the canvas (#F1F0E8).
    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 40 / 255, green: 40 / 255, blue: 37 / 255, alpha: 1)
        }
        return UIColor(red: 241 / 255, green: 240 / 255, blue: 232 / 255, alpha: 1)
    })

    /// Hairline — opacity, not a drawn shadow.
    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(red: 44 / 255, green: 44 / 255, blue: 44 / 255, alpha: 0.08)
    })

    /// Selected wash — charcoal at 8%, never a loud campus blue.
    static let selectWash = Color.ink.opacity(0.08)

    /// Open / positive — Tolan green #01A858.
    static let openGreen = Color(red: 1 / 255, green: 168 / 255, blue: 88 / 255)
    static let busyOrange = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let crowdedRed = Color(red: 225 / 255, green: 29 / 255, blue: 72 / 255)
}

enum ZotFont {
    /// PostScript family registered via UIAppFonts (variable wght/wdth).
    static let family = "Instrument Sans"

    static func face(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(family, size: size, relativeTo: style)
    }

    /// Screen titles — regular, like Tolan. Presence from size, not weight.
    static func hero(_ size: CGFloat = 34) -> Font {
        face(size, relativeTo: .largeTitle)
    }

    static let cardTitle = face(17, relativeTo: .headline).weight(.medium)
    static let sectionTitle = face(15, relativeTo: .subheadline).weight(.medium)
    static let body = face(17, relativeTo: .body)
    static let caption = face(13, relativeTo: .caption)
    static let pill = face(15, relativeTo: .subheadline).weight(.medium)
}

// MARK: - Motion (soft springs — presence, not bounce)

enum ZotMotion {
    static let select = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let soft = Animation.spring(response: 0.48, dampingFraction: 0.86)
    static let appear = Animation.spring(response: 0.55, dampingFraction: 0.88)
}

// MARK: - Radius tokens (one language of rounding everywhere)

/// Cards and sheets — Tolan’s 15pt language.
let zotCardRadius: CGFloat = 15
/// Rows and tiles nested inside cards.
let zotInnerRadius: CGFloat = 12
/// Chips — fully pill.
let zotChipRadius: CGFloat = 999

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
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
