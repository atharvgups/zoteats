import Foundation

/// WidgetKit reload for Dining Status — hall open/close countdowns plus,
/// when the medium Quietest tip is "Libraries closed", the same morning open
/// probes as the Quietest Library widget (Waitz has no parseable hours).
public enum DiningStatusReload {
    public static func boundaries(
        now: Date = Date(),
        countdownEnds: [Date],
        librariesClosed: Bool
    ) -> [Date] {
        var dates = countdownEnds
        dates.append(contentsOf: QuietestLibraryReload.boundaries(
            now: now,
            anyLibraryOpen: !librariesClosed
        ))
        return dates
    }

    public static func nextReload(
        now: Date = Date(),
        countdownEnds: [Date],
        librariesClosed: Bool,
        maxInterval: TimeInterval = 20 * 60
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                now: now,
                countdownEnds: countdownEnds,
                librariesClosed: librariesClosed
            ),
            maxInterval: maxInterval
        )
    }
}
