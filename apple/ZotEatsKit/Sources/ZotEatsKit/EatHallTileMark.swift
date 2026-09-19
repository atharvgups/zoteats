import Foundation

/// Eat hall selector — three equal text-only boxes. Blend A+B:
/// large centered names (A) with a small centered status line (B).
/// Not left-aligned paragraph blocks.
public enum EatHallTileMark: Sendable {
    /// Shared large heavy size for Anteatery / Brandywine / Oasis.
    /// Bigger than Breakfast / Lunch / Dinner pills (17pt).
    public static let namePointSize: CGFloat = 26

    /// Floor if the longest name must shrink to fit — applied to every hall.
    public static let nameMinimumPointSize: CGFloat = 16

    /// Closed / Dinner / Coming Soon — small under the name.
    public static let statusPointSize: CGFloat = 12

    /// Kept for layout math; tiles no longer show a second status line.
    public static let statusSecondaryPointSize: CGFloat = 12

    /// Compact box — name + one status line, not a paragraph card.
    public static let tileHeight: CGFloat = 88

    /// One-line title block — names never wrap mid-word.
    public static let nameBlockHeight: CGFloat = 34

    /// Single small status under the name.
    public static let statusBlockHeight: CGFloat = 18

    /// Same inset stroke for selected and idle so layout size never changes.
    public static let borderWidth: CGFloat = 1

    public static let horizontalPadding: CGFloat = 6

    public static let verticalPadding: CGFloat = 18

    /// Longest compact name — every title is sized to this, not to itself.
    public static let longestCompactName = "Brandywine"

    /// Extra width vs UIKit/SwiftUI metrics so “Brandywine” stays one line.
    public static let nameFitSlack: CGFloat = 1.08

    /// Scale every hall name to the same point size that fits `longestCompactName`.
    public static func fittedNamePointSize(textWidth: CGFloat) -> CGFloat {
        let maxSize = namePointSize
        let minSize = nameMinimumPointSize
        guard textWidth > 0 else { return maxSize }
        // Conservative SF Pro Heavy advance so Oasis never out-sizes Brandywine.
        let needed = CGFloat(longestCompactName.count) * maxSize * 0.72 * nameFitSlack
        if needed <= textWidth { return maxSize }
        return max(minSize, (maxSize * textWidth / needed * 10).rounded() / 10)
    }

    /// Name + status + vertical insets fill the tile with no leftover pad.
    public static var contentFillsTile: Bool {
        nameBlockHeight + statusBlockHeight + verticalPadding * 2 == tileHeight
    }
}
