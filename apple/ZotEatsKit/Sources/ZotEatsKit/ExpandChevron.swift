import Foundation

/// Collapsible controls: right when closed, down when open.
public enum ExpandChevron: Sendable {
    public static func systemName(isExpanded: Bool) -> String {
        isExpanded ? "chevron.down" : "chevron.right"
    }
}
