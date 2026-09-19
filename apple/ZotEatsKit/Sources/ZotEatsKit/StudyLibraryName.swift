import Foundation

/// Waitz still says “Science Library”; students know that building as Gateway.
/// Study only lists these two buildings — no Student Center, Grunigen, or
/// other library-like Waitz rows until they have live floor busyness.
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

    /// The two Study libraries. Hours-only Student Center and other Waitz
    /// "library" hits stay off this tab.
    public static func isStudyLibrary(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        if lower.contains("student center") { return false }
        return lower.contains("langson")
            || lower.contains("science")
            || lower.contains("sci lib")
            || lower.contains("gateway")
    }

    public static func studyLibraries(from facilities: [BusynessPoint]) -> [BusynessPoint] {
        facilities.filter { isStudyLibrary($0.name) }
    }
}
