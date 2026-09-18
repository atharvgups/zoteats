import Foundation

/// Which Live Activities still count as an active tracked meal for Eat UI /
/// auto-start. Ended activities may linger briefly for post-close chrome /
/// deep links (`MealActivityLinger`) — they must not own `trackedKey`.
public enum MealActivitySync {
    public static func isLive(endsAt: Date, now: Date = Date()) -> Bool {
        endsAt > now
    }
}
