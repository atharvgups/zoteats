import Foundation

/// Layout knobs for the Dining Halls Home Screen widget so a third commons
/// fits on both small and medium as one-line meal + clock rows.
public enum DiningStatusLayout {
    /// How many hall rows to show. Bigger tiles add dishes / campus / study,
    /// not a longer hall list — there are only three commons.
    public static func hallLimit(isCompact: Bool, isLarge: Bool = false) -> Int {
        _ = isCompact
        _ = isLarge
        return 3
    }

    public static func usesDenseRows(hallCount: Int) -> Bool {
        hallCount >= 3
    }

    /// Large Dining Halls is a combo: halls + board + campus + study.
    public static func showsStudyFooter(isCompact: Bool, isLarge: Bool = false) -> Bool {
        !isCompact && isLarge
    }

    public static func showsBoardStrip(isCompact: Bool) -> Bool {
        !isCompact
    }

    public static func showsCampusStrip(isLarge: Bool) -> Bool {
        isLarge
    }

    public static func boardDishLimit(isLarge: Bool) -> Int {
        isLarge ? 5 : 3
    }

    public static func campusRowLimit(isLarge: Bool) -> Int {
        isLarge ? 3 : 2
    }

    /// Outer VStack spacing between header and the halls card.
    public static func rowSpacing(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 8 : 10
        }
        return dense ? 8 : 12
    }

    /// Spacing between hall rows inside the nested card.
    public static func hallRowSpacing(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 8 : 10
        }
        return dense ? 9 : 11
    }

    /// Primary hall name font size — fixed so short names (Oasis) don't
    /// render bigger than Anteatery / Brandywine.
    public static func nameFontSize(isCompact: Bool, hallCount: Int) -> Double {
        _ = hallCount
        return isCompact ? 11 : 12
    }

    /// Clock on the trailing side — same size for every row, including Soon.
    public static func statusFontSize(isCompact: Bool, hallCount: Int) -> Double {
        _ = hallCount
        return isCompact ? 12 : 13
    }

    public static let trailingColumnMinWidth: Double = 58
}
