import Foundation

/// Pure helpers for menu-drop detection — which future days sit outside the
/// published `/dateRange` window (and which ones just entered it).
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
    /// excluding any already notified.
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
