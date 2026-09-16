import Foundation

/// Eat hall selector — three identical text-only boxes. No glyphs.
public enum EatHallTileMark: Sendable {
    /// Shared large bold size for Anteatery / Brandywine / Oasis.
    public static let namePointSize: CGFloat = 18

    /// Floor if the longest name must shrink to fit — applied to every hall.
    public static let nameMinimumPointSize: CGFloat = 12

    /// Shared status size (Soon / Breakfast / Coming Soon).
    public static let statusPointSize: CGFloat = 13

    /// Fixed box height — selected chrome must not grow this.
    public static let tileHeight: CGFloat = 144

    /// One-line title block — names never wrap mid-word.
    public static let nameBlockHeight: CGFloat = 28

    /// Reserved status block — fits “Coming Soon” without clipping.
    public static let statusBlockHeight: CGFloat = 36

    /// Same inset stroke for selected and idle so layout size never changes.
    public static let borderWidth: CGFloat = 1

    public static let horizontalPadding: CGFloat = 8

    public static let verticalPadding: CGFloat = 16

    /// Longest compact name — every title is sized to this, not to itself.
    public static let longestCompactName = "Brandywine"

    /// Extra width vs UIKit/SwiftUI metrics so “Brandywine” stays one line.
    public static let nameFitSlack: CGFloat = 1.2

    /// Scale every hall name to the same point size that fits `longestCompactName`.
    public static func fittedNamePointSize(textWidth: CGFloat) -> CGFloat {
        let maxSize = namePointSize
        let minSize = nameMinimumPointSize
        guard textWidth > 0 else { return maxSize }
        // Conservative SF Pro Bold advance so Oasis never out-sizes Brandywine.
        let needed = CGFloat(longestCompactName.count) * maxSize * 0.72 * nameFitSlack
        if needed <= textWidth { return maxSize }
        return max(minSize, (maxSize * textWidth / needed * 10).rounded() / 10)
    }
}
