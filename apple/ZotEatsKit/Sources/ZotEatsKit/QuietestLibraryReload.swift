import Foundation

/// Reload boundaries for the Quietest Library widget.
/// Waitz rarely exposes parseable open/close times (`hourSummary` is often just
/// `"open"`), so when libraries are closed we probe typical morning open hours
/// plus Irvine midnight — otherwise StandBy can sit on "Libraries closed" for
/// nearly an hour after campus libraries reopen.
public enum QuietestLibraryReload {
    /// Irvine minutes for common UCI library open times (no live parseable hours).
    public static let morningOpenMinutes = [7 * 60, 8 * 60, 9 * 60]

    public static func boundaries(
        now: Date = Date(),
        anyLibraryOpen: Bool
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        guard !anyLibraryOpen else { return dates }

        let nowMinutes = UCITime.nowMinutes(now: now)
        for minutes in morningOpenMinutes {
            dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
        }
        return dates
    }

    public static func nextReload(
        now: Date = Date(),
        anyLibraryOpen: Bool
    ) -> Date {
        WidgetRefreshMath.nextQuietestReload(
            now: now,
            anyLibraryOpen: anyLibraryOpen,
            boundaries: boundaries(now: now, anyLibraryOpen: anyLibraryOpen)
        )
    }
}
