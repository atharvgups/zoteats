import Foundation
import ActivityKit
import ZotEatsKit

/// Starts and stops the "meal ends soon" Live Activity (lock screen +
/// Dynamic Island countdown). One meal tracked at a time — tracking a new
/// one replaces the old (end completes before the next request).
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

    /// System Live Activities switch (Settings → Face ID & Passcode / app Live Activities).
    static var systemActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isAvailable: Bool {
        Self.systemActivitiesEnabled
    }

    func isTracking(hall: String, period: String) -> Bool {
        trackedKey == MealTrackMath.key(hallID: hall, period: period)
    }

    /// Reconcile in-memory `trackedKey` with Live Activities that survived
    /// process death or Eat tab unload. Call before reading Tracking UI or
    /// auto-starting — otherwise we recreate / lie about "Track meal".
    ///
    /// Also bounds post-close linger: past `MealActivityLinger` → immediate
    /// dismiss; meal just ended → ask the system to clear at dismissalDate so
    /// overnight Islands don't sit on “has ended” forever.
    func syncFromSystem(now: Date = Date()) {
        let activities = Activity<MealActivityAttributes>.activities
        // Linger cleanup is best-effort; Tracking UI only needs the live set.
        Task {
            for activity in activities {
                let endsAt = activity.content.state.endsAt
                if MealActivityLinger.shouldDismiss(endsAt: endsAt, now: now) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    continue
                }
                guard MealActivityLinger.isLingering(endsAt: endsAt, now: now) else { continue }
                // Already system-ended with a dismissal date — don't re-end.
                if activity.activityState == .ended || activity.activityState == .dismissed {
                    continue
                }
                let dismissal = MealActivityLinger.dismissalDate(endsAt: endsAt)
                await activity.end(nil, dismissalPolicy: .after(dismissal))
            }
        }

        let live = activities
            .filter { MealActivitySync.isLive(endsAt: $0.content.state.endsAt, now: now) }

        guard let best = live.max(by: { $0.content.state.endsAt < $1.content.state.endsAt }) else {
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

    /// Start (or replace) a meal countdown. Awaits ending any prior activity
    /// before requesting so replace doesn't silently no-op. Returns whether
    /// ActivityKit accepted the new activity.
    @discardableResult
    func track(
        hallName: String,
        hallID: String,
        period: String,
        endsAt: Date,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        opensTomorrowPeriod: String? = nil,
        haptic: Bool = true
    ) async -> Bool {
        guard isAvailable else {
            trackedKey = nil
            return false
        }
        await endAll()

        let attributes = MealActivityAttributes(hallName: hallName, period: period, hallID: hallID)
        let state = MealActivityAttributes.ContentState(
            endsAt: endsAt,
            postClosePeriod: postClosePeriod,
            postCloseDate: postCloseDate,
            opensTomorrowPeriod: opensTomorrowPeriod
        )
        do {
            // Keep content fresh through the post-close linger window.
            let stale = MealActivityLinger.staleDate(endsAt: endsAt)
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: stale)
            )
            trackedKey = MealTrackMath.key(hallID: hallID, period: period)
            if haptic { Haptics.soft() }
            return true
        } catch {
            trackedKey = nil
            return false
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
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        opensTomorrowPeriod: String? = nil,
        nowMinutes: Int = UCITime.nowMinutes(),
        now: Date = Date()
    ) async -> Bool {
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
            .contains { MealActivitySync.isLive(endsAt: $0.content.state.endsAt, now: now) }
        if live { return false }
        let endsAt = MealTrackMath.endsAt(
            endMinutes: endMinutes,
            nowMinutes: nowMinutes,
            now: now
        )
        return await track(
            hallName: hallName,
            hallID: hallID,
            period: period,
            endsAt: endsAt,
            postClosePeriod: postClosePeriod,
            postCloseDate: postCloseDate,
            opensTomorrowPeriod: opensTomorrowPeriod,
            haptic: false
        )
    }

    /// Recompute post-close from fresh hall boards while a Live Activity is
    /// still live or lingering — Lunch/Dinner often publish after track/auto-start.
    func refreshPostCloseIfNeeded(
        locations: [DiningLocation],
        now: Date = Date()
    ) {
        let activities = Activity<MealActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        let halls = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })

        Task {
            for activity in activities {
                let endsAt = activity.content.state.endsAt
                if MealActivityLinger.shouldDismiss(endsAt: endsAt, now: now) {
                    continue
                }
                guard let hallID = Self.resolveHallID(
                    explicit: activity.attributes.hallID,
                    hallName: activity.attributes.hallName
                ),
                    let location = halls[hallID],
                    let endMinutes = MealActivityPostClose.trackedPeriodEndMinutes(
                        trackedPeriod: activity.attributes.period,
                        timedPeriods: location.periods
                    )
                else { continue }

                let fresh = MealActivityPostClose.destination(
                    currentPeriodEndMinutes: endMinutes,
                    timedPeriods: location.periods,
                    opensTomorrowPeriod: location.opensTomorrowPeriod,
                    now: now,
                    opensNextPeriod: location.opensNextPeriod,
                    opensNextDayOffset: location.opensNextDayOffset,
                    opensNextDateISO: location.opensNextDateISO
                )
                let state = activity.content.state
                guard MealActivityPostClose.needsRefresh(
                    currentPeriod: state.postClosePeriod,
                    currentDate: state.postCloseDate,
                    fresh: fresh
                ) else { continue }

                let updated = MealActivityAttributes.ContentState(
                    endsAt: endsAt,
                    postClosePeriod: fresh.period,
                    postCloseDate: fresh.date,
                    opensTomorrowPeriod: MealActivityPostClose.contentOpensTomorrowPeriod(
                        postClose: fresh,
                        hallOpensTomorrowPeriod: location.opensTomorrowPeriod
                    )
                )
                let stale = MealActivityLinger.staleDate(endsAt: endsAt)
                await activity.update(ActivityContent(state: updated, staleDate: stale))
            }
        }
    }

    func endAll() async {
        trackedKey = nil
        let activities = Activity<MealActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
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
