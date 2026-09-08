import Foundation

/// Waitz still says “Science Library”; students know that building as Gateway.
public enum StudyLibraryName: Sendable {
    /// Card / hours / quietest chrome — Langson and Gateway, not the Waitz string.
    public static func display(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("langson") { return "Langson" }
        if lower.contains("science") || lower.contains("sci lib") || lower.contains("gateway") {
            return "Gateway"
        }
        return raw
    }
}
