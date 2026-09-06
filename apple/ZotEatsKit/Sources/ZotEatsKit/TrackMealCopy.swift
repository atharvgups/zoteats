import Foundation

/// Favorites on the live board — used if a meal is added to My Plate in bulk.
public enum TrackMealPlateItems: Sendable {
    public static func favorites(
        from stations: [MenuStation],
        favoriteNames: Set<String>
    ) -> [MenuItem] {
        guard !favoriteNames.isEmpty else { return [] }
        var seen = Set<String>()
        var items: [MenuItem] = []
        for station in stations {
            for item in station.items {
                let key = item.name
                guard favoriteNames.contains(key), seen.insert(key).inserted else { continue }
                items.append(item)
            }
        }
        return items
    }
}
