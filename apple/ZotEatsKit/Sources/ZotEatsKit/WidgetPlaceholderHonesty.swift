import Foundation

/// Home Screen widget first-paint / gallery contract.
///
/// WidgetKit can show `placeholder` and preview snapshots before the timeline
/// finishes. Those must never invent a busy-% (TypicalBusyness for halls, or a
/// fake Langson 8%). Paint today's App Group snapshot when it exists; otherwise
/// ask the user to open Anteats — gallery may use shape-only rows with nil %.
public enum WidgetPlaceholderHonesty {
    public enum Source: Equatable, Sendable {
        /// Today's App Group snapshot (or last Waitz reading) — real names/hours.
        case snapshot
        /// Widget gallery chrome only. Occupancy and library % stay nil.
        case gallery
        /// No cache yet — honest "Open Anteats to refresh", not skeleton bars.
        case needsRefresh
    }

    /// Dining-hall occupancy on gallery / first-paint samples. Always nil —
    /// hall % is TypicalBusyness, not live sensors (`FeatureFlags.diningHallOccupancy`).
    public static let galleryHallOccupancy: Int? = nil

    /// Quietest-library % on gallery samples. Always nil — never invent 8%.
    public static let galleryLibraryPercent: Int? = nil

    public static func source(hasSnapshot: Bool, isPreview: Bool) -> Source {
        if hasSnapshot { return .snapshot }
        if isPreview { return .gallery }
        return .needsRefresh
    }

    /// Live Waitz % is honest on a snapshot; gallery and empty-cache never invent one.
    public static func libraryPercent(waitzPercent: Int?, source: Source) -> Int? {
        source == .snapshot ? waitzPercent : nil
    }
}
