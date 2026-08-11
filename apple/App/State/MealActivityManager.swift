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
    static let autoStartWindowMinutes = MealTrackMath.autoStartWindowMinutes

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
        trackedKey == MealTrackMath.key(hallID: hall, period: period)
    }

    /// Reconcile in-memory `trackedKey` with Live Activities that survived
    /// process death or Eat tab unload. Call before reading Tracking UI or
    /// auto-starting — otherwise we recreate / lie about "Track meal".
    func syncFromSystem(now: Date = Date()) {
        let activities = Activity<MealActivityAttributes>.activities
        var valid: [Activity<MealActivityAttributes>] = []
        for activity in activities {
            if activity.content.state.endsAt <= now {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            } else {
                valid.append(activity)
            }
        }

        guard let best = valid.max(by: { $0.content.state.endsAt < $1.content.state.endsAt }) else {
            trackedKey = nil
            return
        }

        let attrs = best.attributes
        if let hallID = Self.resolveHallID(explicit: attrs.hallID, hallName: attrs.hallName) {
            trackedKey = MealTrackMath.key(hallID: hallID, period: attrs.period)
        } else {
            // Still block auto-start from stealing an unmapped live activity.
            trackedKey = MealTrackMath.key(hallID: "unknown", period: attrs.period)
        }
    }

    func track(hallName: String, hallID: String, period: String, endsAt: Date, haptic: Bool = true) {
        guard isAvailable else { return }
        endAll()

        let attributes = MealActivityAttributes(hallName: hallName, period: period, hallID: hallID)
        let state = MealActivityAttributes.ContentState(endsAt: endsAt)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endsAt)
            )
            trackedKey = MealTrackMath.key(hallID: hallID, period: period)
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
        nowMinutes: Int = UCITime.nowMinutes(),
        now: Date = Date()
    ) -> Bool {
        guard isAvailable else { return false }
        guard MealTrackMath.shouldAutoStart(
            nowMinutes: nowMinutes,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            alreadyTracking: trackedKey != nil,
            autoEnabled: Self.autoStartEnabled
        ) else { return false }
        // Belt-and-suspenders if sync couldn't map hallID but ActivityKit still has one.
        let live = Activity<MealActivityAttributes>.activities
            .contains { $0.content.state.endsAt > now }
        if live { return false }
        let endsAt = MealTrackMath.endsAt(
            endMinutes: endMinutes,
            nowMinutes: nowMinutes,
            now: now
        )
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

    static func key(hallID: String, period: String) -> String {
        MealTrackMath.key(hallID: hallID, period: period)
    }

    static func resolveHallID(explicit: String?, hallName: String) -> String? {
        if let explicit, !explicit.isEmpty { return explicit }
        return HallDirectory.id(matchingDisplayName: hallName)
    }
}
