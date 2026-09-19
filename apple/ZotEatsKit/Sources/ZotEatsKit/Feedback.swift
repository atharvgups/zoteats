import Foundation

/// Public Anteats Google Form. Settings and the occasional in-app prompt
/// both open this same URL.
public enum FeedbackForm {
    public static let url = URL(string:
        "https://docs.google.com/forms/d/e/1FAIpQLSesZHPTDKKyD0lZ2EXUPtfCdAhWvdi6eT8RgchWjtDqWFXzMw/viewform"
    )!
}

/// Persisted prompt bookkeeping. Pure data; the app stores it in UserDefaults.
public struct FeedbackPromptState: Equatable, Sendable, Codable {
    public var firstSeenAt: Date?
    public var lastSessionAt: Date?
    public var sessionCount: Int
    public var lastPromptAt: Date?
    public var dismissCount: Int
    public var optedOut: Bool

    public init(
        firstSeenAt: Date? = nil,
        lastSessionAt: Date? = nil,
        sessionCount: Int = 0,
        lastPromptAt: Date? = nil,
        dismissCount: Int = 0,
        optedOut: Bool = false
    ) {
        self.firstSeenAt = firstSeenAt
        self.lastSessionAt = lastSessionAt
        self.sessionCount = sessionCount
        self.lastPromptAt = lastPromptAt
        self.dismissCount = dismissCount
        self.optedOut = optedOut
    }

    public static let empty = FeedbackPromptState()
}

/// When (and whether) to ask for feedback. No UI, no storage.
///
/// Rules:
/// - Not on first open. Needs several sessions and a few days of use.
/// - At most once every ~2.5 weeks after a prompt is shown.
/// - Soft dismiss ("Not now") starts that cooldown. Three dismisses opts out.
/// - "Don't ask again" or opening the form from the prompt opts out for good.
public enum FeedbackPromptPolicy {
    public static let minimumSessions = 4
    public static let minimumInstallDays = 3
    public static let cooldownDays = 18
    public static let maxDismissCount = 3
    /// Rapid foregrounding (lock screen, Control Center) is one session.
    public static let sessionGap: TimeInterval = 4 * 60 * 60
    /// Wait after becoming active so launch sheets and first paint settle.
    public static let presentDelay: TimeInterval = 10

    private static let day: TimeInterval = 86_400

    /// Record an app-became-active. Counts a new session only after `sessionGap`.
    public static func noteLaunch(_ state: FeedbackPromptState, at now: Date) -> FeedbackPromptState {
        var next = state
        if next.firstSeenAt == nil {
            next.firstSeenAt = now
        }
        if let last = next.lastSessionAt, now.timeIntervalSince(last) < sessionGap {
            return next
        }
        next.sessionCount += 1
        next.lastSessionAt = now
        return next
    }

    public static func shouldPrompt(_ state: FeedbackPromptState, at now: Date) -> Bool {
        guard !state.optedOut else { return false }
        guard state.dismissCount < maxDismissCount else { return false }
        guard state.sessionCount >= minimumSessions else { return false }
        guard let first = state.firstSeenAt else { return false }
        guard now.timeIntervalSince(first) >= TimeInterval(minimumInstallDays) * day else { return false }
        if let last = state.lastPromptAt {
            guard now.timeIntervalSince(last) >= TimeInterval(cooldownDays) * day else { return false }
        }
        return true
    }

    public static func notePromptShown(_ state: FeedbackPromptState, at now: Date) -> FeedbackPromptState {
        var next = state
        next.lastPromptAt = now
        return next
    }

    public static func noteDismissed(_ state: FeedbackPromptState) -> FeedbackPromptState {
        var next = state
        next.dismissCount += 1
        if next.dismissCount >= maxDismissCount {
            next.optedOut = true
        }
        return next
    }

    public static func noteOptOut(_ state: FeedbackPromptState) -> FeedbackPromptState {
        var next = state
        next.optedOut = true
        return next
    }

    public static func noteOpenedForm(_ state: FeedbackPromptState) -> FeedbackPromptState {
        var next = state
        next.optedOut = true
        return next
    }
}
