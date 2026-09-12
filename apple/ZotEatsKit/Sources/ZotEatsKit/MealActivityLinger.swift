import Foundation

/// How long a meal Live Activity may stay on lock screen / Island after
/// `endsAt` for “has ended” chrome and post-close deep links — then dismiss.
public enum MealActivityLinger {
    /// Matches historical `staleDate` padding on `Activity.request`.
    public static let lingerInterval: TimeInterval = 30 * 60

    public static func staleDate(endsAt: Date) -> Date {
        endsAt.addingTimeInterval(lingerInterval)
    }

    /// When the system should clear the ended activity (same wall as stale).
    public static func dismissalDate(endsAt: Date) -> Date {
        staleDate(endsAt: endsAt)
    }

    /// Past the linger window — dismiss immediately on sync.
    public static func shouldDismiss(endsAt: Date, now: Date = Date()) -> Bool {
        now >= dismissalDate(endsAt: endsAt)
    }

    /// Meal over but still within the post-close linger window.
    public static func isLingering(endsAt: Date, now: Date = Date()) -> Bool {
        now >= endsAt && !shouldDismiss(endsAt: endsAt, now: now)
    }
}
