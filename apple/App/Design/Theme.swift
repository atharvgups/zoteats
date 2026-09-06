import SwiftUI
import ZotEatsKit

// Anteats visual system — UCI sunrise / sunset canvas, white cards, one gold
// accent. Chrome is hairlines. Type is SF Pro at normal app weights.

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

    /// Solid foot of AppCanvas — ink-bar text, never a page fill.
    static let screen = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 10 / 255, green: 10 / 255, blue: 11 / 255, alpha: 1)
        }
        return UIColor(red: 252 / 255, green: 251 / 255, blue: 248 / 255, alpha: 1)
    })

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

    /// Gold that still reads on the sunrise wash (full #FFD200 washes out in light).
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
    /// Sized SF Pro. Callers add medium / semibold / bold.
    static func face(_ size: CGFloat, relativeTo _: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Screen titles — bold SF Pro.
    static func hero(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Stock iOS text styles at normal weights — not the 11–13pt skinny tokens.
    static let cardTitle = Font.headline.weight(.semibold)
    /// Station / section headers — same thick SF Pro as dish names, a touch larger.
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let body = Font.body
    static let caption = Font.callout
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

    /// Root page / sheet fill — sunrise in light, sunset in dark.
    func appCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { AppCanvas() }
    }
}

/// Shared canvas — follows Settings → App background (persisted).
struct AppCanvas: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppCanvasPreset.storageKey) private var presetRaw = AppCanvasPreset.fallback.rawValue

    var body: some View {
        AppCanvasPaint(
            preset: AppCanvasPreset.resolved(raw: presetRaw),
            dark: colorScheme == .dark
        )
        .ignoresSafeArea()
        .animation(.snappy(duration: 0.28), value: presetRaw)
        .animation(.snappy(duration: 0.28), value: colorScheme)
    }
}

/// Paints one preset in light or dark — used by the page fill and Settings swatches.
struct AppCanvasPaint: View {
    let preset: AppCanvasPreset
    var dark: Bool

    var body: some View {
        Group {
            if preset.usesSystemFill {
                Color(uiColor: dark ? .systemBackground : UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1))
            } else if preset.usesMesh, let colors = preset.meshColors(dark: dark) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0.0, 0.0), .init(0.5, 0.04), .init(1.0, 0.0),
                        .init(0.04, 0.5), .init(0.48, 0.52), .init(0.96, 0.48),
                        .init(0.0, 1.0), .init(0.5, 0.96), .init(1.0, 1.0)
                    ],
                    colors: colors.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
                )
            } else if let stops = preset.linearStops(dark: dark) {
                LinearGradient(
                    stops: stops.map {
                        Gradient.Stop(
                            color: Color(red: $0.red, green: $0.green, blue: $0.blue),
                            location: $0.location
                        )
                    },
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
    }
}

/// Tiny sunrise | sunset thumbnail for the Settings picker.
struct AppCanvasSwatch: View {
    let preset: AppCanvasPreset

    var body: some View {
        HStack(spacing: 0) {
            AppCanvasPaint(preset: preset, dark: false)
            AppCanvasPaint(preset: preset, dark: true)
        }
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
