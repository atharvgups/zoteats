import Foundation

/// Pure Irvine-day checks for Plate Builder persistence.
/// The app-lifetime `PlateStore` must clear when the calendar rolls past
/// midnight in Irvine — init-only reset misses warm overnight launches.
public enum PlateDayMath {
    /// Entries to keep for `todayISO`. Empty when the saved day is missing or stale.
    public static func entriesIfCurrentDay(
        savedDateISO: String?,
        entries: [PlateEntry],
        todayISO: String
    ) -> [PlateEntry] {
        guard let savedDateISO, !savedDateISO.isEmpty, savedDateISO == todayISO else {
            return []
        }
        return entries
    }

    /// True when persisted plate data belongs to a previous Irvine day.
    public static func shouldClear(savedDateISO: String?, todayISO: String) -> Bool {
        guard let savedDateISO, !savedDateISO.isEmpty else { return false }
        return savedDateISO != todayISO
    }
}
