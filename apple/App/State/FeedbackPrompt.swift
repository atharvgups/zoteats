import Foundation
import Observation
import SwiftUI
import ZotEatsKit

/// Owns prompt persistence and the "is something else on screen" gate.
/// Policy lives in ZotEatsKit so the timing rules can be unit-tested.
@MainActor
@Observable
final class FeedbackPromptController {
    private static let storageKey = "zoteats.feedbackPrompt.state"

    var isOffering = false
    var showForm = false
    private(set) var blockCount = 0
    private var offerGeneration = 0

    var isBlocked: Bool { blockCount > 0 || Self.isAutomationLaunch }

    func pushBlock() {
        blockCount += 1
        if isOffering {
            isOffering = false
        }
    }

    func popBlock() {
        blockCount = max(0, blockCount - 1)
    }

    func noteBecameActive() {
        guard !Self.isAutomationLaunch else { return }
        save(FeedbackPromptPolicy.noteLaunch(load(), at: Date()))
        scheduleOfferIfNeeded()
    }

    func dismissSoft() {
        isOffering = false
        save(FeedbackPromptPolicy.noteDismissed(load()))
    }

    func optOut() {
        isOffering = false
        save(FeedbackPromptPolicy.noteOptOut(load()))
    }

    func accept() {
        isOffering = false
        save(FeedbackPromptPolicy.noteOpenedForm(load()))
        showForm = true
    }

    private func scheduleOfferIfNeeded() {
        offerGeneration += 1
        let generation = offerGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FeedbackPromptPolicy.presentDelay))
            guard generation == offerGeneration else { return }
            presentIfEligible()
        }
    }

    private func presentIfEligible() {
        guard !isOffering, !isBlocked else { return }
        let now = Date()
        var state = load()
        guard FeedbackPromptPolicy.shouldPrompt(state, at: now) else { return }
        state = FeedbackPromptPolicy.notePromptShown(state, at: now)
        save(state)
        isOffering = true
    }

    private func load() -> FeedbackPromptState {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let state = try? JSONDecoder().decode(FeedbackPromptState.self, from: data)
        else { return .empty }
        return state
    }

    private func save(_ state: FeedbackPromptState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Screenshots, the demo tour, and XCTest should never see the prompt.
    static var isAutomationLaunch: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-showSettings") || args.contains("-campusMenu") { return true }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
        return false
    }
}

private struct FeedbackPromptBlockModifier: ViewModifier {
    @Environment(FeedbackPromptController.self) private var prompt: FeedbackPromptController?
    let blocked: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                if blocked { prompt?.pushBlock() }
            }
            .onDisappear {
                if blocked { prompt?.popBlock() }
            }
            .onChange(of: blocked) { wasBlocked, isBlocked in
                if isBlocked, !wasBlocked { prompt?.pushBlock() }
                if !isBlocked, wasBlocked { prompt?.popBlock() }
            }
    }
}

extension View {
    /// Hide the feedback prompt while a sheet or other blocking UI is up.
    func blocksFeedbackPrompt(_ blocked: Bool) -> some View {
        modifier(FeedbackPromptBlockModifier(blocked: blocked))
    }
}

/// Soft card. Not a system alert, so it cannot trap the user or stack on alerts.
struct FeedbackPromptCard: View {
    let onShare: () -> Void
    let onLater: () -> Void
    let onNever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How is Anteats going?")
                        .font(ZotFont.cardTitle)
                    Text("A short form helps us fix what is broken and keep what you like.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onLater) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary, .quaternary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not now")
            }

            HStack(spacing: 8) {
                Button("Share feedback", action: onShare)
                    .font(ZotFont.pill.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.uciBlue, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)

                Button("Not now", action: onLater)
                    .font(ZotFont.pill)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }

            Button("Don't ask again", action: onNever)
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }
}
