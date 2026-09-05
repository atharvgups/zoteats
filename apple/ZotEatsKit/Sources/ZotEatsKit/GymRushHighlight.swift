import Foundation

/// Which hour the Gym "Today at the ARC" strip paints as now.
/// Nil when closed so the typical chart stays a day plan without a live marker.
public enum GymRushHighlight {
    public static func currentHour(openNow: Bool, nowMinutes: Int) -> Int? {
        guard openNow else { return nil }
        return nowMinutes / 60
    }
}
