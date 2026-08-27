import Foundation

/// Meal pill pin after an Eat deep link that preserved an explicit period.
/// Survives programmatic hall/date settle from deep-link apply; App clears it
/// only when the user changes hall, DayStrip day, or meal pill (not via
/// `onChange` of hall/date — those also fire when the link itself settles).
public enum EatDeepLinkMealPin {
    /// Pin to hold after resolving a preserved deep-link meal.
    public static func pin(
        preserveRequestedMeal: Bool,
        resolvedPeriod: String?
    ) -> String? {
        guard preserveRequestedMeal else { return nil }
        return resolvedPeriod
    }
}
