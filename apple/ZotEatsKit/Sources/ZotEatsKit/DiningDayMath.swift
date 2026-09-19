import Foundation

/// Pure Irvine-day checks for the app-lifetime `DiningStore`.
/// Live menus are keyed with a literal `"today"` suffix — without a rollover
/// purge, warm overnight launches keep yesterday's dishes on Eat.
public enum DiningDayMath {
    /// True when locations were loaded on a previous Irvine calendar day.
    public static func shouldRollover(loadedDateISO: String?, todayISO: String) -> Bool {
        guard let loadedDateISO, !loadedDateISO.isEmpty else { return false }
        return loadedDateISO != todayISO
    }

    /// Menu cache keys for the live (non-browsing) day use `|today` as the date slot.
    public static func isLiveTodayMenuKey(_ key: String) -> Bool {
        key.hasSuffix("|today")
    }

    /// Drop live `"today"` menus; keep future-day browse keys (`|2026-07-17`).
    public static func liveTodayMenuKeys(in keys: [String]) -> [String] {
        keys.filter(isLiveTodayMenuKey)
    }
}
