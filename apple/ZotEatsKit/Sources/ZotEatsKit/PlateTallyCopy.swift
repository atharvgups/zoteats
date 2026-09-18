import Foundation

/// My Plate chrome copy — chip, floating tally, and browse-ahead affordance.
public enum PlateTallyCopy {
    /// Header chip when the floating tally isn't showing.
    public static func chipTitle(count: Int) -> String {
        count <= 0 ? "My Plate" : "My Plate · \(count)"
    }

    /// Blue floating bar while viewing today with dishes on the plate.
    public static func barTitle(count: Int) -> String {
        count == 1 ? "1 on your plate" : "\(max(count, 0)) on your plate"
    }

    /// Quiet bar while browsing a future day so today's plate doesn't vanish.
    public static func browseAheadTitle(count: Int) -> String {
        count == 1 ? "Today's plate · 1" : "Today's plate · \(max(count, 0))"
    }

    /// Calorie card / bar figure — honest zero when the plate is empty.
    public static func caloriesValue(_ calories: Int) -> String {
        "\(max(calories, 0)) cal"
    }

    /// Protein card figure.
    public static func proteinValue(_ proteinG: Int) -> String {
        "\(max(proteinG, 0))g"
    }

    /// Running macros on the floating tally (today and browse-ahead).
    public static func macrosLine(calories: Int, proteinG: Int) -> String {
        "\(caloriesValue(calories)) · \(proteinValue(proteinG)) protein"
    }
}
