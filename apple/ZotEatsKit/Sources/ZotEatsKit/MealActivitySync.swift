import Foundation

/// Which Live Activities still count as an active tracked meal for Eat UI /
/// auto-start. Ended activities linger for post-close chrome and deep links —
/// they must not own `trackedKey` or get `.immediate` dismissed on sync.
public enum MealActivitySync {
    public static func isLive(endsAt: Date, now: Date = Date()) -> Bool {
        endsAt > now
    }
}
