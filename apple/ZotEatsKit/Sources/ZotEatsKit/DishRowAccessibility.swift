import Foundation

/// VoiceOver for Eat / Campus menu dish rows — name, calories, diet tags, and
/// "Contains …" allergens (detail-sheet honesty); description stays out of the label.
public enum DishRowAccessibility {
    public static func label(
        dishName: String,
        calories: Int?,
        dietaryTags: [String],
        allergens: [String],
        stars: Int? = nil
    ) -> String {
        let name = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = [name.isEmpty ? "Dish" : name]

        if let calories {
            parts.append("\(calories) calories")
        }

        for tag in dietaryTags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
        }

        for allergen in allergens {
            let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parts.append("Contains \(trimmed)")
            }
        }

        if let stars, stars > 0 {
            parts.append(MealReviewAccessibility.starsLabel(stars))
        }

        return parts.joined(separator: ", ")
    }
}
