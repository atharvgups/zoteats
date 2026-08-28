import SwiftUI

// Anteats visual system — quiet paper, one gold accent, type as hierarchy.
// Light is warm parchment; dark is a first-class near-black, not a dimmed
// invert. Chrome is hairlines. Presence comes from size and air, not weight
// or colored pills. Instrument Sans (SIL OFL) is the one grotesque.

extension Color {
    /// UCI primary blue (#0064A4) — cheer easter egg only, never chrome.
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200) — the one accent.
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for the cheer gradient (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Primary ink — charcoal on paper, cream on dark.
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 247 / 255, green: 244 / 255, blue: 234 / 255, alpha: 1)
            : UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 1)
    })

    /// Secondary copy — same ink, quieter.
    static let inkMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 247 / 255, green: 244 / 255, blue: 234 / 255, alpha: 0.58)
            : UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 0.50)
    })

    /// Page canvas — parchment #F4F2E7 / near-black in dark (not a grey lift).
    static let screen = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 16 / 255, green: 16 / 255, blue: 14 / 255, alpha: 1)
        }
        return UIColor(red: 244 / 255, green: 242 / 255, blue: 231 / 255, alpha: 1)
    })

    /// Raised surface — a hair brighter than the page, so cards don't box.
    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 1)
        }
        return UIColor(red: 250 / 255, green: 249 / 255, blue: 242 / 255, alpha: 1)
    })

    /// Hairline — opacity, never a shadow.
    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 0.10)
    })

    /// Selected wash — charcoal at 6%, never campus blue.
    static let selectWash = Color.ink.opacity(0.06)

    /// Gold that still reads on parchment (full #FFD200 washes out in light).
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 210 / 255, blue: 0 / 255, alpha: 1)
            : UIColor(red: 168 / 255, green: 122 / 255, blue: 0 / 255, alpha: 1)
    })

    /// Open / positive — quiet green, not a second brand color.
    static let openGreen = Color(red: 1 / 255, green: 168 / 255, blue: 88 / 255)
    static let busyOrange = Color(red: 214 / 255, green: 140 / 255, blue: 32 / 255)
    static let crowdedRed = Color(red: 196 / 255, green: 62 / 255, blue: 74 / 255)
}

enum ZotFont {
    /// PostScript family registered via UIAppFonts (variable wght/wdth).
    static let family = "Instrument Sans"

    static func face(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(family, size: size, relativeTo: style)
    }

    /// Screen titles — regular. Presence from size and tracking, not weight.
    static func hero(_ size: CGFloat = 36) -> Font {
        face(size, relativeTo: .largeTitle)
    }

    static let cardTitle = face(18, relativeTo: .headline)
    static let sectionTitle = face(13, relativeTo: .subheadline).weight(.medium)
    static let body = face(16, relativeTo: .body)
    static let caption = face(13, relativeTo: .caption)
    static let pill = face(14, relativeTo: .subheadline).weight(.medium)
    static let kicker = face(11, relativeTo: .caption2).weight(.medium)
}

// MARK: - Motion (soft springs — presence, not bounce)

enum ZotMotion {
    static let select = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let soft = Animation.spring(response: 0.52, dampingFraction: 0.90)
    static let appear = Animation.spring(response: 0.60, dampingFraction: 0.92)
}

// MARK: - Radius tokens

/// Eat hall heroes — large rounded, not the list language.
let zotHallRadius: CGFloat = 20
/// Cards and sheets.
let zotCardRadius: CGFloat = 16
/// Rows nested inside cards.
let zotInnerRadius: CGFloat = 10
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

/// Hairline rule — leading inset so lists read as one surface, not boxes.
struct ZotHairline: View {
    var leading: CGFloat = 16

    var body: some View {
        Color.cardBorder
            .frame(height: 1)
            .padding(.leading, leading)
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
