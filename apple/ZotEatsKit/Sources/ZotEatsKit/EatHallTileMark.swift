import Foundation

/// Eat hall pill-tile marks — custom Mesa / hobbit / desert-water, same name size.
public enum EatHallTileMark: String, Sendable {
    case mesa
    case hobbit
    case oasis

    /// Shared bold SF Pro size so Anteatery / Brandywine / Oasis never shrink.
    public static let namePointSize: CGFloat = 15

    /// Rounded-rect tile height — wide enough to read as a pill, not a circle.
    public static let tileMinHeight: CGFloat = 112

    public static func kind(forHallID id: String) -> EatHallTileMark {
        if HallDirectory.isOasis(id) { return .oasis }
        switch id.lowercased() {
        case "anteatery": return .mesa
        case "brandywine": return .hobbit
        default: return .mesa
        }
    }
}
