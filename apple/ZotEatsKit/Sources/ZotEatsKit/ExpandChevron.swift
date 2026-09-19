import Foundation

/// Collapsible controls: right when closed, down when open.
/// Rows that are not expandable must not show a chevron at all.
public enum ExpandChevron: Sendable {
    public static func systemName(isExpanded: Bool) -> String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    /// `nil` when the row has nothing to expand (Campus single-location cards).
    public static func systemName(isExpanded: Bool, isExpandable: Bool) -> String? {
        isExpandable ? systemName(isExpanded: isExpanded) : nil
    }
}
