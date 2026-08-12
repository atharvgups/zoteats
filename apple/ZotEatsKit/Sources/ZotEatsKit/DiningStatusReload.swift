import Foundation

/// WidgetKit reload for Dining Status — every hall's meal open/close (and
/// tomorrow opens / Irvine midnight), matching Today's Menu honesty, plus
/// Quietest Waitz reopen / morning probes when the medium tip is "Libraries closed".
public enum DiningStatusReload {
    public static func boundaries(
        locations: [DiningLocation],
        nowMinutes: Int,
        now: Date = Date(),
        librariesClosed: Bool,
        libraryReopenMinutes: [Int] = []
    ) -> [Date] {
        var dates = TodaysMenuReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now
        )
        dates.append(contentsOf: QuietestLibraryReload.boundaries(
            now: now,
            anyLibraryOpen: !librariesClosed,
            reopenMinutes: libraryReopenMinutes
        ))
        return dates
    }

    public static func nextReload(
        locations: [DiningLocation],
        nowMinutes: Int,
        now: Date = Date(),
        librariesClosed: Bool,
        libraryReopenMinutes: [Int] = [],
        maxInterval: TimeInterval = 20 * 60
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                locations: locations,
                nowMinutes: nowMinutes,
                now: now,
                librariesClosed: librariesClosed,
                libraryReopenMinutes: libraryReopenMinutes
            ),
            maxInterval: maxInterval
        )
    }
}
