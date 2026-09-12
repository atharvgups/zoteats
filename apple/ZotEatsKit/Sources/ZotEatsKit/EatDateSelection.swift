import Foundation

/// Keep Eat’s day strip on the live board once an explicit ISO becomes Irvine today
/// (e.g. user left “tomorrow” selected overnight).
public enum EatDateSelection {
    /// `nil` = live today. Collapse an ISO that matches `todayISO` back to `nil`.
    public static func snapLiveToday(selectedDateISO: String?, todayISO: String) -> String? {
        guard let selectedDateISO, !selectedDateISO.isEmpty else { return nil }
        return selectedDateISO == todayISO ? nil : selectedDateISO
    }
}
