import Foundation

/// In-app Study schedule refresh — same Waitz reopen probes, Irvine midnight,
/// and open/closed Waitz cadence as the Quietest Library widget, so the
/// Quietest hero, crowding, and Status pills flip while the Study tab stays open.
public enum StudyBoundaryRefresh {
    /// Matches Quietest widget: library pool when present, else whole feed.
    public static func anyLibraryOpen(from facilities: [BusynessPoint]) -> Bool {
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries
        return pool.contains(where: \.isOpen)
    }

    public static func nextFire(
        now: Date = Date(),
        facilities: [BusynessPoint]
    ) -> Date {
        QuietestLibraryReload.nextReload(
            now: now,
            anyLibraryOpen: anyLibraryOpen(from: facilities),
            reopenMinutes: QuietestLibraryReload.reopenMinutes(from: facilities)
        )
    }
}
