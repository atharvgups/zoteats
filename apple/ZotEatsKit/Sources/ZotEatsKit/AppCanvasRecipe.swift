import Foundation

/// Softened UCI sunrise / sunset stops — blue → gold horizon, not marketing swatches.
public enum AppCanvasRecipe: Sendable {
    public struct Stop: Sendable, Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let location: Double
    }

    /// Light: washed UCI Blue → faint champagne gold → near-white.
    public static let sunrise: [Stop] = [
        Stop(red: 184 / 255, green: 214 / 255, blue: 232 / 255, location: 0),
        Stop(red: 214 / 255, green: 228 / 255, blue: 236 / 255, location: 0.30),
        Stop(red: 246 / 255, green: 240 / 255, blue: 220 / 255, location: 0.54),
        Stop(red: 252 / 255, green: 251 / 255, blue: 248 / 255, location: 1),
    ]

    /// Dark: deep navy → washed amber → near-black.
    public static let sunset: [Stop] = [
        Stop(red: 6 / 255, green: 22 / 255, blue: 42 / 255, location: 0),
        Stop(red: 14 / 255, green: 32 / 255, blue: 54 / 255, location: 0.30),
        Stop(red: 46 / 255, green: 34 / 255, blue: 16 / 255, location: 0.54),
        Stop(red: 10 / 255, green: 10 / 255, blue: 11 / 255, location: 1),
    ]
}
