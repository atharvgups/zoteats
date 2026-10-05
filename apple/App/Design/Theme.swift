import SwiftUI
import ZotEatsKit

// Anteats visual system — plain white / system-dark canvas, white cards, one gold
// accent. Chrome is hairlines. Type is thick SF Pro — never ultraLight / thin.

extension Color {
    /// UCI primary blue (#0064A4) — cheer easter egg only, never chrome.
    static let uciBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
    /// UCI gold (#FFD200) — the one accent.
    static let uciGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)
    /// Deeper blue for the cheer gradient (#004A7C).
    static let uciBlueDeep = Color(red: 0 / 255, green: 74 / 255, blue: 124 / 255)

    /// Primary ink — system label (cool, not cream).
    static let ink = Color(uiColor: .label)

    /// Secondary copy — system secondary label.
    static let inkMuted = Color(uiColor: .secondaryLabel)

    /// Ink-bar text on filled capsules — system page color, never beige.
    static let screen = Color(uiColor: .systemBackground)

    /// Raised surface — pure white in light, system elevated in dark.
    static let card = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .secondarySystemGroupedBackground
        }
        return .white
    })

    /// Hairline — opacity, never a shadow.
    static let cardBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 28 / 255, green: 27 / 255, blue: 24 / 255, alpha: 0.10)
    })

    /// Selected wash — charcoal at 6%, never campus blue.
    static let selectWash = Color.ink.opacity(0.06)

    /// Gold that still reads on white (full #FFD200 washes out in light).
    static let accentUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 255 / 255, green: 210 / 255, blue: 0 / 255, alpha: 1)
            : UIColor(red: 168 / 255, green: 122 / 255, blue: 0 / 255, alpha: 1)
    }

    static let accent = Color(uiColor: accentUIColor)

    /// Open / positive — quiet green, not a second brand color.
    static let openGreen = Color(red: 1 / 255, green: 168 / 255, blue: 88 / 255)
    static let busyOrange = Color(red: 214 / 255, green: 140 / 255, blue: 32 / 255)
    static let crowdedRed = Color(red: 196 / 255, green: 62 / 255, blue: 74 / 255)
}

enum ZotFont {
    /// Sized SF Pro — medium floor so body never goes thin.
    static func face(_ size: CGFloat, relativeTo _: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Screen titles — bold SF Pro.
    static func hero(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Stock iOS text styles at medium+ — never ultraLight / thin.
    static let cardTitle = Font.headline.weight(.semibold)
    /// Station / floor headers — same thick SF Pro as dish names, a touch larger.
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let body = Font.body.weight(.medium)
    static let caption = Font.callout.weight(.medium)
    static let pill = Font.subheadline.weight(.semibold)
    static let kicker = Font.subheadline.weight(.semibold)
}

/// System UISwitch — gold when on, system well + knob when off.
/// Leave the thumb system-default so dark-mode switches keep a visible knob.
enum ZotSwitch {
    static func configure() {
        UISwitch.appearance().onTintColor = Color.accentUIColor
        UISwitch.appearance().thumbTintColor = nil
    }
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

    /// Root page / sheet fill — system white in light, system dark in dark.
    func appCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { AppCanvas() }
    }
}

/// Shared canvas — plain system background. No gradient. No color picker.
struct AppCanvas: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
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

/// Soft desaturated tags that sit calmly on white cards.
enum TagPalette {
    static let sage = Color(red: 68 / 255, green: 131 / 255, blue: 97 / 255)
    static let eucalyptus = Color(red: 89 / 255, green: 148 / 255, blue: 132 / 255)
    static let slate = Color(red: 84 / 255, green: 118 / 255, blue: 159 / 255)
    static let plum = Color(red: 132 / 255, green: 104 / 255, blue: 156 / 255)
    static let ochre = Color(red: 158 / 255, green: 124 / 255, blue: 76 / 255)
    static let clay = Color(red: 147 / 255, green: 110 / 255, blue: 90 / 255)
    static let terracotta = Color(red: 178 / 255, green: 106 / 255, blue: 87 / 255)

    struct ChipLook {
        let foreground: Color
        let background: Color
    }

    /// Notion-style muted pastel: soft fill, slightly darker same-hue text.
    private static func pastel(
        lightFill: (CGFloat, CGFloat, CGFloat),
        darkFill: (CGFloat, CGFloat, CGFloat),
        lightText: (CGFloat, CGFloat, CGFloat),
        darkText: (CGFloat, CGFloat, CGFloat)
    ) -> ChipLook {
        ChipLook(
            foreground: Color(uiColor: UIColor { traits in
                let t = traits.userInterfaceStyle == .dark ? darkText : lightText
                return UIColor(red: t.0, green: t.1, blue: t.2, alpha: 1)
            }),
            background: Color(uiColor: UIColor { traits in
                let t = traits.userInterfaceStyle == .dark ? darkFill : lightFill
                return UIColor(red: t.0, green: t.1, blue: t.2, alpha: 1)
            })
        )
    }

    /// Deeper muted sage — Vegan.
    static let veganChip = pastel(
        lightFill: (216 / 255, 228 / 255, 218 / 255), // #D8E4DA
        darkFill: (53 / 255, 72 / 255, 60 / 255), // #35483C
        lightText: (52 / 255, 90 / 255, 66 / 255), // #345A42
        darkText: (158 / 255, 186 / 255, 166 / 255) // #9EBAA6
    )
    /// Lighter pale green — Vegetarian.
    static let vegetarianChip = pastel(
        lightFill: (232 / 255, 240 / 255, 229 / 255), // #E8F0E5
        darkFill: (61 / 255, 74 / 255, 62 / 255), // #3D4A3E
        lightText: (74 / 255, 112 / 255, 78 / 255), // #4A704E
        darkText: (168 / 255, 190 / 255, 168 / 255) // #A8BEA8
    )
    /// Soft leaf green — Plant Forward.
    static let plantChip = pastel(
        lightFill: (220 / 255, 232 / 255, 214 / 255), // #DCE8D6
        darkFill: (56 / 255, 72 / 255, 54 / 255), // #384836
        lightText: (66 / 255, 102 / 255, 64 / 255), // #426640
        darkText: (156 / 255, 180 / 255, 150 / 255) // #9CB496
    )
    /// Muted blue — Halal.
    static let halalChip = pastel(
        lightFill: (217 / 255, 228 / 255, 238 / 255), // #D9E4EE
        darkFill: (53 / 255, 66 / 255, 80 / 255), // #354250
        lightText: (58 / 255, 90 / 255, 116 / 255), // #3A5A74
        darkText: (152 / 255, 172 / 255, 190 / 255) // #98ACBE
    )
    /// Muted purple — Kosher.
    static let kosherChip = pastel(
        lightFill: (230 / 255, 221 / 255, 234 / 255), // #E6DDEA
        darkFill: (67 / 255, 56 / 255, 74 / 255), // #43384A
        lightText: (96 / 255, 80 / 255, 112 / 255), // #605070
        darkText: (186 / 255, 166 / 255, 194 / 255) // #BAA6C2
    )
    /// Muted tan / yellow — Gluten-Free.
    static let glutenChip = pastel(
        lightFill: (240 / 255, 232 / 255, 212 / 255), // #F0E8D4
        darkFill: (74 / 255, 67 / 255, 54 / 255), // #4A4336
        lightText: (122 / 255, 102 / 255, 64 / 255), // #7A6640
        darkText: (196 / 255, 176 / 255, 137 / 255) // #C4B089
    )

    static func dietColor(_ tag: String) -> Color {
        chipLook(tag: tag, fallback: .secondary).foreground
    }

    /// Soft Notion pastels for the diet row. Allergens keep the terracotta wash.
    static func chipLook(tag: String, fallback: Color) -> ChipLook {
        switch tag.lowercased() {
        case "vegan": veganChip
        case "vegetarian": vegetarianChip
        case "plant forward", "plant powered": plantChip
        case "halal": halalChip
        case "kosher": kosherChip
        case "gluten-free", "gluten free": glutenChip
        default:
            ChipLook(foreground: fallback, background: fallback.opacity(0.10))
        }
    }

    static let allergenColor: Color = terracotta
}

// MARK: - Busyness level presentation

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
