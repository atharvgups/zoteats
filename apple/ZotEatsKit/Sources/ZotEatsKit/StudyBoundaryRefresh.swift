import Foundation

/// In-app Study schedule refresh — same Waitz reopen / close probes, Irvine
/// midnight, and open/closed Waitz cadence as the Quietest Library widget, so
/// the Quietest hero, crowding, and Status pills flip while the Study tab stays open.
public enum StudyBoundaryRefresh {
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
        return QuietestLibraryReload.nextReload(
            now: now,
            anyLibraryOpen: anyLibraryOpen(from: facilities, nowMinutes: nowMinutes),
            reopenMinutes: QuietestLibraryReload.reopenMinutes(from: facilities),
            closeMinutes: QuietestLibraryReload.closeMinutes(
                from: facilities,
                nowMinutes: nowMinutes
            )
        )
    }
}
