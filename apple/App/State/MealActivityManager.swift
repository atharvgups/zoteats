import Foundation
import ActivityKit
import ZotEatsKit

/// Starts and stops the "meal ends soon" Live Activity (lock screen +
/// Dynamic Island countdown). One meal tracked at a time — tracking a new
/// one replaces the old.
@MainActor
@Observable
final class MealActivityManager {
    private(set) var trackedKey: String?

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func isTracking(hall: String, period: String) -> Bool {
        trackedKey == "\(hall)|\(period)"
    }

    func track(hallName: String, hallID: String, period: String, endsAt: Date) {
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
            Haptics.soft()
        } catch {
            trackedKey = nil
        }
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
