import Foundation

/// Empty-state copy when a Campus type filter (and optional Open Now) hides every row.
public enum CampusCategoryEmptyCopy {
    /// Message under “Nothing's open in Coffee” / “Nothing in Markets”.
    /// When Open Now is on, prefer a filter-scoped next-open hint.
    public static func message(
        openOnly: Bool,
        hint: CampusNextOpenHint.Hint?
    ) -> String {
        if openOnly {
            if let hint {
                return "\(hint.line). Clear the filter, or show closed spots."
            }
            return "Try clearing the type filter, or show closed spots from the chip."
        }
        return "Clear the type filter to see other campus spots."
    }

    /// Places matching the selected type filter for a scoped next-open lookup.
    public static func places(
        matching filter: CampusTypeFilter,
        from all: [CampusPlace]
    ) -> [CampusPlace] {
        all.filter { filter.matches(category: $0.category) }
    }

    /// Legacy string category helper (tests / callers that still pass hub labels).
    public static func places(
        inCategory category: String?,
        from all: [CampusPlace]
    ) -> [CampusPlace] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}
