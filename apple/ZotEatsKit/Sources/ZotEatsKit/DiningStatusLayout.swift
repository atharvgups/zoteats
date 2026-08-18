import Foundation

/// Layout knobs for the Dining Halls Home Screen widget so a third commons
/// fits on both small and medium as one-line meal + clock rows.
public enum DiningStatusLayout {
    /// How many hall rows to show. Small/medium show 3; large earns more room.
    public static func hallLimit(isCompact: Bool, isLarge: Bool = false) -> Int {
        _ = isCompact
        if isLarge { return 6 }
        return 3
    }

    public static func usesDenseRows(hallCount: Int) -> Bool {
        hallCount >= 3
    }

    /// Dining Halls is halls-only — Study has its own widget.
    public static func showsStudyFooter(isCompact: Bool) -> Bool {
        _ = isCompact
        return false
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

    /// Primary hall name font size (expanded display type runs wide).
    public static func nameFontSize(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 12 : 13
        }
        return dense ? 13 : 14
    }

    /// Clock on the trailing side.
    public static func statusFontSize(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 12 : 13
        }
        return dense ? 14 : 16
    }
}
