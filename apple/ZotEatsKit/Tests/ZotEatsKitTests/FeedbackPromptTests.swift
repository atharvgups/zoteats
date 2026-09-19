import Foundation
import Testing
@testable import ZotEatsKit

@Suite("FeedbackPromptPolicy")
struct FeedbackPromptTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 86_400

    private func used(
        sessions: Int,
        daysInstalled: Double,
        lastPromptDaysAgo: Double? = nil,
        dismissCount: Int = 0,
        optedOut: Bool = false
    ) -> FeedbackPromptState {
        FeedbackPromptState(
            firstSeenAt: start,
            lastSessionAt: start.addingTimeInterval(daysInstalled * day),
            sessionCount: sessions,
            lastPromptAt: lastPromptDaysAgo.map { start.addingTimeInterval((daysInstalled - $0) * day) },
            dismissCount: dismissCount,
            optedOut: optedOut
        )
    }

    private func now(daysInstalled: Double) -> Date {
        start.addingTimeInterval(daysInstalled * day)
    }

    @Test func firstLaunchDoesNotPrompt() {
        let state = FeedbackPromptPolicy.noteLaunch(.empty, at: start)
        #expect(state.sessionCount == 1)
        #expect(state.firstSeenAt == start)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: start))
    }

    @Test func rapidRelaunchesCountAsOneSession() {
        var state = FeedbackPromptPolicy.noteLaunch(.empty, at: start)
        state = FeedbackPromptPolicy.noteLaunch(state, at: start.addingTimeInterval(30 * 60))
        state = FeedbackPromptPolicy.noteLaunch(state, at: start.addingTimeInterval(3 * 60 * 60))
        #expect(state.sessionCount == 1)
    }

    @Test func sessionGapCountsANewSession() {
        var state = FeedbackPromptPolicy.noteLaunch(.empty, at: start)
        state = FeedbackPromptPolicy.noteLaunch(state, at: start.addingTimeInterval(4 * 60 * 60))
        #expect(state.sessionCount == 2)
    }

    @Test func fewSessionsStillTooSoon() {
        let state = used(sessions: 3, daysInstalled: 10)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 10)))
    }

    @Test func enoughSessionsButNotEnoughDays() {
        let state = used(sessions: 8, daysInstalled: 2)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 2)))
    }

    @Test func eligibleAfterSeveralSessionsAndDays() {
        let state = used(sessions: 4, daysInstalled: 3)
        #expect(FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 3)))
    }

    @Test func cooldownBlocksARepeat() {
        let state = used(sessions: 10, daysInstalled: 20, lastPromptDaysAgo: 17)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 20)))
    }

    @Test func cooldownExpiresAfterEighteenDays() {
        let state = used(sessions: 10, daysInstalled: 21, lastPromptDaysAgo: 18)
        #expect(FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 21)))
    }

    @Test func threeDismissesOptsOut() {
        var state = used(sessions: 6, daysInstalled: 10)
        state = FeedbackPromptPolicy.noteDismissed(state)
        state = FeedbackPromptPolicy.noteDismissed(state)
        #expect(!state.optedOut)
        #expect(FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 10)))
        state = FeedbackPromptPolicy.noteDismissed(state)
        #expect(state.optedOut)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 40)))
    }

    @Test func dontAskAgainNeverPrompts() {
        let state = FeedbackPromptPolicy.noteOptOut(used(sessions: 10, daysInstalled: 30))
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 90)))
    }

    @Test func openingTheFormNeverPromptsAgain() {
        let state = FeedbackPromptPolicy.noteOpenedForm(used(sessions: 10, daysInstalled: 30))
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: now(daysInstalled: 90)))
    }

    @Test func showingThePromptStartsTheCooldown() {
        var state = used(sessions: 5, daysInstalled: 5)
        let shownAt = now(daysInstalled: 5)
        state = FeedbackPromptPolicy.notePromptShown(state, at: shownAt)
        #expect(!FeedbackPromptPolicy.shouldPrompt(state, at: shownAt.addingTimeInterval(2 * day)))
        #expect(FeedbackPromptPolicy.shouldPrompt(state, at: shownAt.addingTimeInterval(18 * day)))
    }

    @Test func formURLIsThePublicGoogleForm() {
        #expect(FeedbackForm.url.absoluteString.contains("1FAIpQLSesZHPTDKKyD0lZ2EXUPtfCdAhWvdi6eT8RgchWjtDqWFXzMw"))
        #expect(FeedbackForm.url.path.hasSuffix("/viewform"))
    }
}
