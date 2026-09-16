import Foundation

/// VoiceOver hint copy for selectable pills — deselectable rows get a clear/select
/// hint; Eat meal periods (`allowsDeselect: false`) rely on the selected trait alone.
public enum PillSelectionAccessibility {
    public static func hint(
        title: String,
        isSelected: Bool,
        allowsDeselect: Bool
    ) -> String? {
        guard allowsDeselect else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return isSelected ? "Clears selection" : "Selects \(name)"
    }
}
