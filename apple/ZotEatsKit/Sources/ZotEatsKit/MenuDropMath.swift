import Foundation

/// Pure helpers for menu-drop detection — which upcoming days sit outside the
/// published `/dateRange` window (and which ones just entered it).
///
/// Watch set must include **today**: a day seeded as unpublished “tomorrow”
/// often publishes overnight, and by the next BG check that ISO is Irvine
/// today — excluding it silently drops the ping.
public enum MenuDropMath {
    /// Days still waiting on UCI to publish (ISO date outside [earliest, latest]).
    public static func unpublishedDays(
        upcoming: [String],
        earliest: String,
        latest: String
    ) -> Set<String> {
        Set(upcoming.filter { $0 < earliest || $0 > latest })
    }

    /// Previously unpublished days that are now inside the published window,
    /// excluding any already notified. `nowPublished` should include today
    /// when that ISO is in `/dateRange` (overnight rollover recovery).
    public static func newlyDroppedDays(
        previouslyUnpublished: Set<String>,
        nowPublished: Set<String>,
        alreadyNotified: Set<String>
    ) -> Set<String> {
        previouslyUnpublished
            .intersection(nowPublished)
            .subtracting(alreadyNotified)
    }
}
