import Foundation

/// Layout knobs for the Dining Halls Home Screen widget so a third commons
/// fits on both small and medium as one-line meal + clock rows.
public enum DiningStatusLayout {
    /// How many hall rows to show. Small and medium are the same story —
    /// next meal / open status across the three commons.
    public static let hallLimit = 3

    public static func usesDenseRows(hallCount: Int) -> Bool {
        hallCount >= 3
    }

    /// Outer VStack spacing between header and the halls list.
    public static func rowSpacing(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 10 : 12
        }
        return dense ? 10 : 14
    }

    /// Spacing between hall rows.
    public static func hallRowSpacing(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 10 : 12
        }
        return dense ? 11 : 13
    }

    /// Primary hall name — thick SF Pro, same size on every row.
    public static func nameFontSize(isCompact: Bool, hallCount: Int) -> Double {
        _ = hallCount
        return isCompact ? 16 : 17
    }

    /// Clock on the trailing side — same size for every row, including Soon.
    public static func statusFontSize(isCompact: Bool, hallCount: Int) -> Double {
        _ = hallCount
        return isCompact ? 18 : 19
    }

    public static let trailingColumnMinWidth: Double = 58
}
