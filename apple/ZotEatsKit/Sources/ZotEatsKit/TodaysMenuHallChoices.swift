import Foundation

/// Pure options for the Today's Menu widget hall picker.
/// Keeps Auto + live `/restaurants` halls in API order so a third commons
/// appears in Edit Widget without an AppEnum code change.
public enum TodaysMenuHallChoices {
    public struct Option: Equatable, Sendable {
        public let id: String
        public let title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    public static let autoID = "auto"
    public static let autoTitle = "Auto"

    /// `auto` first, then each location. Empty/offline → `auto` + `HallDirectory.fallbackIDs`.
    public static func options(from locations: [DiningLocation]) -> [Option] {
        var result = [Option(id: autoID, title: autoTitle)]
        if locations.isEmpty {
            for id in HallDirectory.fallbackIDs {
                result.append(Option(id: id, title: HallDirectory.displayName(for: id)))
            }
            return result
        }
        for hall in locations where !hall.isComingSoon {
            let title = hall.name.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(Option(
                id: hall.id,
                title: title.isEmpty ? HallDirectory.displayName(for: hall.id) : title
            ))
        }
        return result
    }
}
