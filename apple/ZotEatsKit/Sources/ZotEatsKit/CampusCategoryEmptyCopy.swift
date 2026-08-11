import Foundation

/// Empty-state copy when a Campus category pill (and optional Open Now) hides every row.
public enum CampusCategoryEmptyCopy {
    /// Message under “Nothing's open in Coffee” / “Nothing in Markets”.
    /// When Open Now is on, prefer a category-scoped next-open hint.
    public static func message(
        openOnly: Bool,
        hint: CampusNextOpenHint.Hint?
    ) -> String {
        if openOnly {
            if let hint {
                return "\(hint.line). Clear the category, or show closed spots."
            }
            return "Try clearing the category filter, or show closed spots from the chip."
        }
        return "Clear the category filter to see other campus spots."
    }

    /// Places in the selected category for a scoped next-open lookup.
    public static func places(
        inCategory category: String?,
        from all: [CampusPlace]
    ) -> [CampusPlace] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}
