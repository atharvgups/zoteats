import Foundation

/// Eat hall selector — three identical text-only boxes. No glyphs.
public enum EatHallTileMark: Sendable {
    /// Shared large bold size for Anteatery / Brandywine / Oasis.
    public static let namePointSize: CGFloat = 20

    /// Floor if the longest name must shrink to fit — applied to every hall.
    public static let nameMinimumPointSize: CGFloat = 14

    /// Shared status size (Soon / Breakfast / Coming Soon).
    public static let statusPointSize: CGFloat = 13

    /// Fixed box height — selected chrome must not grow this.
    public static let tileHeight: CGFloat = 144

    /// Reserved title block — two lines so wrap never changes card size.
    public static let nameBlockHeight: CGFloat = 48

    /// Reserved status block — fits “Coming Soon” without clipping.
    public static let statusBlockHeight: CGFloat = 36

    /// Same stroke for selected and idle so layout size never changes.
    public static let borderWidth: CGFloat = 2

    public static let horizontalPadding: CGFloat = 10

    public static let verticalPadding: CGFloat = 16

    /// Longest compact name — every title is sized to this, not to itself.
    public static let longestCompactName = "Brandywine"

    /// Scale every hall name to the same point size that fits `longestCompactName`.
    public static func fittedNamePointSize(textWidth: CGFloat) -> CGFloat {
        let maxSize = namePointSize
        let minSize = nameMinimumPointSize
        guard textWidth > 0 else { return maxSize }
        // Conservative SF Pro Bold advance (~0.62em) so Oasis never out-sizes Brandywine.
        let needed = CGFloat(longestCompactName.count) * maxSize * 0.62
        if needed <= textWidth { return maxSize }
        return max(minSize, (maxSize * textWidth / needed * 10).rounded() / 10)
    }
}
