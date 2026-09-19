import Foundation

/// VoiceOver for Campus "Open now" — selected trait + honest toggle hint
/// (label alone used to imply state without `.isSelected`).
public enum CampusOpenNowAccessibility {
    public static func label(openOnly: Bool) -> String {
        openOnly ? "Showing open spots only" : "Showing all spots"
    }

    public static func hint(openOnly: Bool) -> String {
        openOnly ? "Shows closed spots again" : "Hides closed spots"
    }
}
