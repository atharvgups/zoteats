import Foundation

/// WidgetKit reload for Dining Status — every hall's meal open/close (and
/// tomorrow opens / Irvine midnight), matching Today's Menu honesty, plus
/// Quietest Waitz reopen / morning probes when the medium tip is "Libraries closed".
/// While the Quietest tip is live-open, cadence matches Quietest/Study (10m).
public enum DiningStatusReload {
    /// Hall / closed-tip cadence (matches Campus / Quietest-closed).
    public static let defaultMaxInterval: TimeInterval = 20 * 60
    /// Live Quietest % tip — same as `WidgetRefreshMath.nextQuietestReload` open.
    public static let quietestOpenMaxInterval: TimeInterval = 10 * 60

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
        quietestTipOpen: Bool = false,
        maxInterval: TimeInterval? = nil
    ) -> Date {
        let interval = maxInterval
            ?? (quietestTipOpen ? quietestOpenMaxInterval : defaultMaxInterval)
        return WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                locations: locations,
                nowMinutes: nowMinutes,
                now: now,
                librariesClosed: librariesClosed,
                libraryReopenMinutes: libraryReopenMinutes
            ),
            maxInterval: interval
        )
    }
}
