import Foundation

/// Eat hall selector — three identical text-only boxes. No glyphs.
public enum EatHallTileMark: Sendable {
    /// Shared large bold size for Anteatery / Brandywine / Oasis.
    public static let namePointSize: CGFloat = 22

    /// Floor if the longest name must shrink to fit — applied to every hall.
    public static let nameMinimumPointSize: CGFloat = 14

    /// Open / Closed / Coming Soon.
    public static let statusPointSize: CGFloat = 16

    /// Meal name under the primary status.
    public static let statusSecondaryPointSize: CGFloat = 15

    /// Fixed box height — selected chrome must not grow this.
    public static let tileHeight: CGFloat = 144

    /// One-line title block — names never wrap mid-word.
    public static let nameBlockHeight: CGFloat = 32

    /// Remaining card under the name — status fills this, no leftover pad.
    public static let statusBlockHeight: CGFloat = 88

    /// Same inset stroke for selected and idle so layout size never changes.
    public static let borderWidth: CGFloat = 1

    public static let horizontalPadding: CGFloat = 10

    public static let verticalPadding: CGFloat = 12

    /// Longest compact name — every title is sized to this, not to itself.
    public static let longestCompactName = "Brandywine"

    /// Extra width vs UIKit/SwiftUI metrics so “Brandywine” stays one line.
    public static let nameFitSlack: CGFloat = 1.12

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

    /// Name + status + vertical insets fill the square with no leftover pad.
    public static var contentFillsTile: Bool {
        nameBlockHeight + statusBlockHeight + verticalPadding * 2 == tileHeight
    }
}
