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
}
