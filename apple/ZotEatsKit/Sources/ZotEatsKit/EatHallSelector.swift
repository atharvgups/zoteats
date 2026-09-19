import Foundation

/// Eat hall tiles: Anteatery / Brandywine / Oasis as equal-width 3-up.
/// Never a horizontal carousel that hides Oasis off-screen.
public enum EatHallSelector: Sendable {
    public static let slotCount = 3
    public static let spacing: CGFloat = 6

    /// Stable Eat order. Extra API halls never steal a fourth tile.
    public static func visible(_ locations: [DiningLocation]) -> [DiningLocation] {
        let anteatery = locations.first { $0.id.caseInsensitiveCompare("anteatery") == .orderedSame }
        let brandywine = locations.first { $0.id.caseInsensitiveCompare("brandywine") == .orderedSame }
        let oasis = locations.first { HallDirectory.isOasis($0.id) }
            ?? (locations.isEmpty ? nil : DiningService.oasisComingSoonLocation())
        return [anteatery, brandywine, oasis].compactMap { $0 }
    }

    /// Width of one of three equal tiles. Always divides by 3, even while loading.
    public static func cardWidth(containerWidth: CGFloat, spacing: CGFloat = spacing) -> CGFloat {
        guard containerWidth > 0 else { return 0 }
        let gaps = CGFloat(slotCount - 1) * spacing
        return max(0, (containerWidth - gaps) / CGFloat(slotCount))
    }

    public static var fillsOneScreenWithoutScrolling: Bool { true }
}
