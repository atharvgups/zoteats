import SwiftUI
import ZotEatsKit

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device Apple Intelligence subtitle for Eat. Returns nil when Foundation
/// Models aren't available so the static meal line stays on screen.
enum EatIntelligenceHeadline {
    static func wittySubtitle(period: String?) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await generate(period: period)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func generate(period: String?) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let meal = EatMealHeadline.mealLabel(period: period)
        let fallback = EatMealHeadline.subtitle(period: period)
        let mealName = meal.isEmpty ? "the current meal" : meal
        let session = LanguageModelSession(
            instructions: """
            You write tiny Eat-tab subtitles for Anteats, a UCI dining app. \
            One line, at most eight words. Witty, campus-friendly, no quotes, \
            no emoji, no hashtags. A small Anteater easter egg is welcome.
            """
        )
        do {
            let response = try await session.respond(
                to: "Selected meal: \(mealName). Write one subtitle."
            )
            let line = EatMealHeadline.sanitizeGenerated(response.content, fallback: fallback)
            return line == fallback ? nil : line
        } catch {
            return nil
        }
    }
    #endif
}
