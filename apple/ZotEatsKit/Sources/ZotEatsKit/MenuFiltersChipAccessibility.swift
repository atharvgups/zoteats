import Foundation

/// Capsule title + VoiceOver for the shared Eat / Campus menu Filters chip.
/// Campus used to show a count-only VO label that dropped the active filter name.
public enum MenuFiltersChipAccessibility {
    public static func title(dietFilters: [String], allergenAvoids: [String]) -> String {
        let diets = cleaned(dietFilters)
        let allergens = cleaned(allergenAvoids)
        let total = diets.count + allergens.count
        if total == 0 { return "Filters" }
        if total == 1, diets.count == 1 { return diets[0] }
        if total == 1, allergens.count == 1 { return "No \(allergens[0])" }
        return "\(total) filters"
    }

    public static func accessibilityLabel(dietFilters: [String], allergenAvoids: [String]) -> String {
        let chip = title(dietFilters: dietFilters, allergenAvoids: allergenAvoids)
        if chip == "Filters" { return "Menu filters" }
        return "Menu filters: \(chip)"
    }

    private static func cleaned(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
