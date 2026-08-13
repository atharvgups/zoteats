import Foundation

/// Layout knobs for the Dining Halls Home Screen widget so a third commons
/// fits on both small and medium without silently dropping a hall.
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

    /// Outer VStack spacing between header / hall rows / quietest footer.
    public static func rowSpacing(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 4 : 7
        }
        return dense ? 5 : 9
    }

    /// Primary hall name font size.
    public static func nameFontSize(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 11 : 12
        }
        return dense ? 12 : 13
    }

    /// Status / countdown secondary line.
    public static func statusFontSize(isCompact: Bool, hallCount: Int) -> Double {
        let dense = usesDenseRows(hallCount: hallCount)
        if isCompact {
            return dense ? 9 : 10
        }
        return dense ? 10 : 11
    }
}
