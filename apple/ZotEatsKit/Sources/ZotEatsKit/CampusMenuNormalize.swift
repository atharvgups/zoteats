import Foundation

/// Normalize Campus menu sections for readable sheets — collapse All Day noise.
public enum CampusMenuNormalize {
    public static let availableAllDay = "Available all day"

    /// Rename All Day → Available all day, dedupe items, then pin that
    /// section after the other stations. Ember still stays last.
    public static func stations(_ raw: [MenuStation]) -> [MenuStation] {
        var allDayItems: [MenuItem] = []
        var allDaySeen = Set<String>()
        var others: [MenuStation] = []

        for station in raw {
            let isAllDay = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("All Day") == .orderedSame
                || station.name.localizedCaseInsensitiveCompare(availableAllDay) == .orderedSame
            if isAllDay {
                for item in station.items {
                    let key = item.name.lowercased()
                    if allDaySeen.insert(key).inserted {
                        allDayItems.append(item)
                    }
                }
            } else {
                others.append(station)
            }
        }

        let pinned = DiningService.pinTwistedRootFirst(others)
        if allDayItems.isEmpty { return pinned }
        let ember = pinned.filter { DiningService.isEmber(stationName: $0.name, stationID: $0.stationID) }
        let rest = pinned.filter { !DiningService.isEmber(stationName: $0.name, stationID: $0.stationID) }
        return rest + [MenuStation(name: availableAllDay, items: allDayItems)] + ember
    }

    public static func isAvailableAllDay(_ stationName: String) -> Bool {
        stationName.localizedCaseInsensitiveCompare(availableAllDay) == .orderedSame
    }
}
