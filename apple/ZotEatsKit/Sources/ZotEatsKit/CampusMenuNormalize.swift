import Foundation

/// Normalize Campus menu sections for readable sheets — collapse All Day noise.
public enum CampusMenuNormalize {
    public static let availableAllDay = "Available all day"

    /// Rename All Day → Available all day, dedupe items, then let the shared
    /// station ranker place that section before desserts and the burger board.
    public static func stations(_ raw: [MenuStation]) -> [MenuStation] {
        var allDayItems: [MenuItem] = []
        var others: [MenuStation] = []

        for station in raw {
            let isAllDay = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("All Day") == .orderedSame
                || station.name.localizedCaseInsensitiveCompare(availableAllDay) == .orderedSame
            if isAllDay {
                allDayItems.append(contentsOf: station.items)
            } else {
                others.append(station.withItems(DiningService.dedupeStationItems(station.items)))
            }
        }

        let uniqueAllDay = DiningService.dedupeStationItems(allDayItems)
        if !uniqueAllDay.isEmpty {
            others.append(MenuStation(name: availableAllDay, items: uniqueAllDay))
        }
        return DiningService.pinTwistedRootFirst(others)
    }

    public static func isAvailableAllDay(_ stationName: String) -> Bool {
        stationName.localizedCaseInsensitiveCompare(availableAllDay) == .orderedSame
    }
}
