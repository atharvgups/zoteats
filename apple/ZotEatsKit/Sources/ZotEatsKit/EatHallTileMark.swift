import Foundation

/// Eat hall pill-tile marks — one SF Symbol per commons, same name size.
public enum EatHallTileMark: Sendable {
    /// Shared bold SF Pro size so Anteatery / Brandywine / Oasis never shrink.
    public static let namePointSize: CGFloat = 15

    /// Mesa Court lodge, abstract Shire leaf-ring, desert-oasis droplet.
    public static func symbolName(forHallID id: String) -> String {
        if HallDirectory.isOasis(id) { return "drop.fill" }
        switch id.lowercased() {
        case "anteatery": return "building.2.fill"
        case "brandywine": return "leaf.circle.fill"
        default: return "fork.knife"
        }
    }
}
