import Foundation

/// Live Activity meal-end math — wall-clock Pacific close, not `now + minutesLeft`
/// (which can run the Island countdown up to ~59s past the real meal end).
public enum MealTrackMath {
    /// Minutes before meal end when auto-track kicks in.
    public static let autoStartWindowMinutes = 45

    /// Irvine wall-clock end for a meal period (start of that minute).
    public static func endsAt(
        endMinutes: Int,
        nowMinutes: Int,
        now: Date = Date()
    ) -> Date {
        UCITime.date(forMinutes: endMinutes, nowMinutes: nowMinutes, now: now)
    }

    /// Whether auto-start should fire (ignores ActivityKit availability).
    public static func shouldAutoStart(
        nowMinutes: Int,
        startMinutes: Int,
        endMinutes: Int,
        alreadyTracking: Bool,
        autoEnabled: Bool
    ) -> Bool {
        guard autoEnabled else { return false }
        guard !alreadyTracking else { return false }
        guard nowMinutes >= startMinutes, nowMinutes < endMinutes else { return false }
        let minutesLeft = endMinutes - nowMinutes
        return minutesLeft > 0 && minutesLeft <= autoStartWindowMinutes
    }

    public static func key(hallID: String, period: String) -> String {
        "\(hallID)|\(period)"
    }
}
