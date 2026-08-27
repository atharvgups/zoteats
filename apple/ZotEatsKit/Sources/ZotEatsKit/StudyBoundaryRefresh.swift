import Foundation

/// In-app Study schedule refresh — same Waitz reopen / close probes and Irvine
/// midnight as the Quietest Library widget, with a tighter occupancy tick
/// while libraries are open so the hero tracks the 60s Waitz TTL. Home Screen
/// widgets keep the slower Quietest cadence (WidgetKit budget).
public enum StudyBoundaryRefresh {
    /// In-app only. Shorter than the widget's 10m open cadence so occupancy
    /// catches the next Waitz TTL while Study stays visible.
    public static let openOccupancyInterval: TimeInterval = 45

    /// Matches Quietest widget: library pool when present, else whole feed.
    /// Honors Waitz Closed-until / ranges over a stale `isOpen` flag.
    public static func anyLibraryOpen(
        from facilities: [BusynessPoint],
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> Bool {
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries
        return pool.contains { $0.isEffectivelyOpen(nowMinutes: nowMinutes) }
    }

    public static func nextFire(
        now: Date = Date(),
        facilities: [BusynessPoint]
    ) -> Date {
        let nowMinutes = UCITime.nowMinutes(now: now)
        let anyOpen = anyLibraryOpen(from: facilities, nowMinutes: nowMinutes)
        let widgetFire = QuietestLibraryReload.nextReload(
            now: now,
            anyLibraryOpen: anyOpen,
            reopenMinutes: QuietestLibraryReload.reopenMinutes(from: facilities),
            closeMinutes: QuietestLibraryReload.closeMinutes(
                from: facilities,
                nowMinutes: nowMinutes
            )
        )
        guard anyOpen else { return widgetFire }
        return min(widgetFire, now.addingTimeInterval(openOccupancyInterval))
    }
}
