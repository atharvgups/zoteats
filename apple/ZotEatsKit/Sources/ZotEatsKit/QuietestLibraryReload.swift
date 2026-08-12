import Foundation

/// Reload boundaries for the Quietest Library widget.
/// While closed, Waitz often ships the real reopen in `hoursSummary`
/// (`"Closed until 8:00am"`); we parse those and keep typical 7/8/9 probes as
/// fallback when the summary is missing or just `"open"`, plus Irvine midnight.
/// While open, parseable Waitz ranges arm their close so Status / Quietest
/// don't wait on the 10m cadence after a holiday early close.
public enum QuietestLibraryReload {
    /// Irvine minutes for common UCI library open times when Waitz has no
    /// parseable reopen time.
    public static let morningOpenMinutes = [7 * 60, 8 * 60, 9 * 60]

    /// Distinct reopen minutes from Waitz `Closed until …` on the library pool
    /// (same pool as Study / Quietest glance).
    public static func reopenMinutes(from facilities: [BusynessPoint]) -> [Int] {
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries
        return Set(pool.compactMap { WaitzHoursSummary.closedUntilMinutes($0.hoursSummary) })
            .sorted()
    }

    /// Distinct close minutes from parseable Waitz ranges on open libraries.
    public static func closeMinutes(from facilities: [BusynessPoint]) -> [Int] {
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries
        return Set(
            pool.filter(\.isOpen).compactMap { WaitzHoursSummary.closeMinutes($0.hoursSummary) }
        ).sorted()
    }

    public static func boundaries(
        now: Date = Date(),
        anyLibraryOpen: Bool,
        reopenMinutes: [Int] = [],
        closeMinutes: [Int] = []
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        let nowMinutes = UCITime.nowMinutes(now: now)

        if anyLibraryOpen {
            for minutes in Set(closeMinutes).sorted() {
                dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
            }
            return dates
        }

        let probes = Set(reopenMinutes).union(morningOpenMinutes)
        for minutes in probes.sorted() {
            dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
        }
        return dates
    }

    public static func nextReload(
        now: Date = Date(),
        anyLibraryOpen: Bool,
        reopenMinutes: [Int] = [],
        closeMinutes: [Int] = []
    ) -> Date {
        WidgetRefreshMath.nextQuietestReload(
            now: now,
            anyLibraryOpen: anyLibraryOpen,
            boundaries: boundaries(
                now: now,
                anyLibraryOpen: anyLibraryOpen,
                reopenMinutes: reopenMinutes,
                closeMinutes: closeMinutes
            )
        )
    }
}
