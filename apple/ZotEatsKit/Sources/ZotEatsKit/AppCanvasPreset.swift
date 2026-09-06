import Foundation

/// Dogfood canvas presets — each has a sunrise (light) and sunset (dark) pair.
public enum AppCanvasPreset: String, CaseIterable, Sendable, Identifiable {
    case blueOnly
    case yellowOnly
    case blueGold
    case goldBlue
    case mesh
    case hybrid
    case system

    public static let storageKey = "zoteats.canvasPreset"
    public static let fallback = AppCanvasPreset.blueGold

    public var id: String { rawValue }

    public static func resolved(raw: String?) -> AppCanvasPreset {
        AppCanvasPreset(rawValue: raw ?? "") ?? .blueGold
    }

    public var label: String {
        switch self {
        case .blueOnly: "Blue only"
        case .yellowOnly: "Yellow only"
        case .blueGold: "Blue → gold"
        case .goldBlue: "Gold → blue"
        case .mesh: "Blue + yellow mesh"
        case .hybrid: "Blue + yellow hybrid (1+2)"
        case .system: "System"
        }
    }

    public var usesMesh: Bool { self == .mesh }
    public var usesSystemFill: Bool { self == .system }

    public func linearStops(dark: Bool) -> [AppCanvasStop]? {
        switch self {
        case .system, .mesh: return nil
        case .blueOnly: return dark ? Self.blueOnlySunset : Self.blueOnlySunrise
        case .yellowOnly: return dark ? Self.yellowOnlySunset : Self.yellowOnlySunrise
        case .blueGold: return dark ? Self.blueGoldSunset : Self.blueGoldSunrise
        case .goldBlue: return dark ? Self.goldBlueSunset : Self.goldBlueSunrise
        case .hybrid: return dark ? Self.hybridSunset : Self.hybridSunrise
        }
    }

    /// 3×3 mesh colors, row-major.
    public func meshColors(dark: Bool) -> [AppCanvasStop]? {
        guard self == .mesh else { return nil }
        return dark ? Self.meshDark : Self.meshLight
    }
}

public struct AppCanvasStop: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let location: Double

    public init(red: Double, green: Double, blue: Double, location: Double = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.location = location
    }
}

extension AppCanvasPreset {
    /// Light: washed UCI Blue → near-white.
    static let blueOnlySunrise: [AppCanvasStop] = [
        AppCanvasStop(red: 184 / 255, green: 214 / 255, blue: 232 / 255, location: 0),
        AppCanvasStop(red: 216 / 255, green: 230 / 255, blue: 238 / 255, location: 0.42),
        AppCanvasStop(red: 252 / 255, green: 251 / 255, blue: 248 / 255, location: 1),
    ]
    /// Dark: deep navy → near-black.
    static let blueOnlySunset: [AppCanvasStop] = [
        AppCanvasStop(red: 6 / 255, green: 22 / 255, blue: 42 / 255, location: 0),
        AppCanvasStop(red: 12 / 255, green: 28 / 255, blue: 48 / 255, location: 0.42),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 11 / 255, location: 1),
    ]

    /// Light: soft UCI gold → cream → white.
    static let yellowOnlySunrise: [AppCanvasStop] = [
        AppCanvasStop(red: 248 / 255, green: 232 / 255, blue: 186 / 255, location: 0),
        AppCanvasStop(red: 252 / 255, green: 244 / 255, blue: 220 / 255, location: 0.42),
        AppCanvasStop(red: 253 / 255, green: 252 / 255, blue: 248 / 255, location: 1),
    ]
    /// Dark: amber → near-black.
    static let yellowOnlySunset: [AppCanvasStop] = [
        AppCanvasStop(red: 56 / 255, green: 38 / 255, blue: 12 / 255, location: 0),
        AppCanvasStop(red: 32 / 255, green: 22 / 255, blue: 10 / 255, location: 0.45),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 11 / 255, location: 1),
    ]

    /// Light: washed UCI Blue → faint champagne → near-white.
    static let blueGoldSunrise: [AppCanvasStop] = [
        AppCanvasStop(red: 184 / 255, green: 214 / 255, blue: 232 / 255, location: 0),
        AppCanvasStop(red: 214 / 255, green: 228 / 255, blue: 236 / 255, location: 0.30),
        AppCanvasStop(red: 246 / 255, green: 240 / 255, blue: 220 / 255, location: 0.54),
        AppCanvasStop(red: 252 / 255, green: 251 / 255, blue: 248 / 255, location: 1),
    ]
    /// Dark: deep navy → washed amber → near-black.
    static let blueGoldSunset: [AppCanvasStop] = [
        AppCanvasStop(red: 6 / 255, green: 22 / 255, blue: 42 / 255, location: 0),
        AppCanvasStop(red: 14 / 255, green: 32 / 255, blue: 54 / 255, location: 0.30),
        AppCanvasStop(red: 46 / 255, green: 34 / 255, blue: 16 / 255, location: 0.54),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 11 / 255, location: 1),
    ]

    /// Light: pale gold → soft blue → white.
    static let goldBlueSunrise: [AppCanvasStop] = [
        AppCanvasStop(red: 248 / 255, green: 236 / 255, blue: 200 / 255, location: 0),
        AppCanvasStop(red: 220 / 255, green: 230 / 255, blue: 236 / 255, location: 0.40),
        AppCanvasStop(red: 198 / 255, green: 218 / 255, blue: 234 / 255, location: 0.62),
        AppCanvasStop(red: 252 / 255, green: 251 / 255, blue: 248 / 255, location: 1),
    ]
    /// Dark: deep amber → indigo → near-black.
    static let goldBlueSunset: [AppCanvasStop] = [
        AppCanvasStop(red: 52 / 255, green: 36 / 255, blue: 12 / 255, location: 0),
        AppCanvasStop(red: 22 / 255, green: 24 / 255, blue: 48 / 255, location: 0.48),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 12 / 255, location: 1),
    ]

    /// Light: dual-stop — soft blue AND soft gold both present, washed.
    static let hybridSunrise: [AppCanvasStop] = [
        AppCanvasStop(red: 184 / 255, green: 214 / 255, blue: 232 / 255, location: 0),
        AppCanvasStop(red: 228 / 255, green: 232 / 255, blue: 218 / 255, location: 0.36),
        AppCanvasStop(red: 246 / 255, green: 230 / 255, blue: 182 / 255, location: 0.58),
        AppCanvasStop(red: 252 / 255, green: 251 / 255, blue: 248 / 255, location: 1),
    ]
    /// Dark: navy AND amber both present.
    static let hybridSunset: [AppCanvasStop] = [
        AppCanvasStop(red: 6 / 255, green: 22 / 255, blue: 42 / 255, location: 0),
        AppCanvasStop(red: 24 / 255, green: 26 / 255, blue: 32 / 255, location: 0.36),
        AppCanvasStop(red: 52 / 255, green: 36 / 255, blue: 14 / 255, location: 0.58),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 11 / 255, location: 1),
    ]

    static let meshLight: [AppCanvasStop] = [
        AppCanvasStop(red: 184 / 255, green: 214 / 255, blue: 232 / 255),
        AppCanvasStop(red: 214 / 255, green: 228 / 255, blue: 236 / 255),
        AppCanvasStop(red: 246 / 255, green: 236 / 255, blue: 200 / 255),
        AppCanvasStop(red: 206 / 255, green: 224 / 255, blue: 234 / 255),
        AppCanvasStop(red: 246 / 255, green: 240 / 255, blue: 220 / 255),
        AppCanvasStop(red: 250 / 255, green: 244 / 255, blue: 214 / 255),
        AppCanvasStop(red: 250 / 255, green: 250 / 255, blue: 248 / 255),
        AppCanvasStop(red: 252 / 255, green: 251 / 255, blue: 248 / 255),
        AppCanvasStop(red: 252 / 255, green: 250 / 255, blue: 244 / 255),
    ]
    static let meshDark: [AppCanvasStop] = [
        AppCanvasStop(red: 6 / 255, green: 22 / 255, blue: 42 / 255),
        AppCanvasStop(red: 14 / 255, green: 28 / 255, blue: 50 / 255),
        AppCanvasStop(red: 48 / 255, green: 34 / 255, blue: 14 / 255),
        AppCanvasStop(red: 16 / 255, green: 22 / 255, blue: 44 / 255),
        AppCanvasStop(red: 28 / 255, green: 24 / 255, blue: 32 / 255),
        AppCanvasStop(red: 46 / 255, green: 32 / 255, blue: 14 / 255),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 12 / 255),
        AppCanvasStop(red: 10 / 255, green: 10 / 255, blue: 11 / 255),
        AppCanvasStop(red: 12 / 255, green: 10 / 255, blue: 10 / 255),
    ]
}
