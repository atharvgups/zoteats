import Foundation

/// Keep Eat’s day strip on the live board once an explicit ISO becomes Irvine today
/// (e.g. user left “tomorrow” selected overnight).
public enum EatDateSelection {
    /// `nil` = live today. Collapse an ISO that matches `todayISO` back to `nil`.
    public static func snapLiveToday(selectedDateISO: String?, todayISO: String) -> String? {
        guard let selectedDateISO, !selectedDateISO.isEmpty else { return nil }
        return selectedDateISO == todayISO ? nil : selectedDateISO
    }

    /// Stay on a day that actually has a board. `nil` means live today when
    /// today is posted; otherwise snap to the soonest posted ISO.
    public static func clampToPosted(
        selectedDateISO: String?,
        todayISO: String,
        postedISOs: Set<String>?
    ) -> String? {
        let selected = snapLiveToday(selectedDateISO: selectedDateISO, todayISO: todayISO)
        guard let postedISOs, !postedISOs.isEmpty else { return selected }

        if let selected {
            if postedISOs.contains(selected) { return selected }
        } else if postedISOs.contains(todayISO) {
            return nil
        }

        let sorted = postedISOs.sorted()
        let next = sorted.first { $0 >= todayISO } ?? sorted.first
        return next == todayISO ? nil : next
    }
}
