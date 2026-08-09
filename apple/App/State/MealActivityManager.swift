import Foundation
import ActivityKit
import ZotEatsKit

/// Starts and stops the "meal ends soon" Live Activity (lock screen +
/// Dynamic Island countdown). One meal tracked at a time — tracking a new
/// one replaces the old.
@MainActor
@Observable
final class MealActivityManager {
    private static let autoEnabledKey = "zoteats.autoMealActivity"
    /// Minutes before meal end when auto-track kicks in.
    static let autoStartWindowMinutes = 45

    private(set) var trackedKey: String?

    /// When on, Eat auto-starts the countdown once a meal is in its final window.
    static var autoStartEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoEnabledKey) }
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isTracking(hall: String, period: String) -> Bool {
        trackedKey == "\(hall)|\(period)"
    }

    func track(hallName: String, hallID: String, period: String, endsAt: Date, haptic: Bool = true) {
        guard isAvailable else { return }
        endAll()

        let attributes = MealActivityAttributes(hallName: hallName, period: period)
        let state = MealActivityAttributes.ContentState(endsAt: endsAt)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endsAt)
            )
            trackedKey = "\(hallID)|\(period)"
            if haptic { Haptics.soft() }
        } catch {
            trackedKey = nil
        }
    }

    /// Start tracking if we're inside the final window and nothing else is tracked.
    @discardableResult
    func autoStartIfNeeded(
        hallName: String,
        hallID: String,
        period: String,
        startMinutes: Int,
        endMinutes: Int,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> Bool {
        guard Self.autoStartEnabled, isAvailable else { return false }
        guard nowMinutes >= startMinutes, nowMinutes < endMinutes else { return false }
        let minutesLeft = endMinutes - nowMinutes
        guard minutesLeft > 0, minutesLeft <= Self.autoStartWindowMinutes else { return false }
        if isTracking(hall: hallID, period: period) { return false }
        // Don't steal a manually tracked different meal.
        if trackedKey != nil { return false }
        let endsAt = Date(timeIntervalSinceNow: TimeInterval(minutesLeft * 60))
        track(hallName: hallName, hallID: hallID, period: period, endsAt: endsAt, haptic: false)
        return trackedKey != nil
    }

    func endAll() {
        trackedKey = nil
        let activities = Activity<MealActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
