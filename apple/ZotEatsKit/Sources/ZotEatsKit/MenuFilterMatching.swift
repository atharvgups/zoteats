import Foundation

/// Shared Eat + Campus dietary / allergen filter matching.
/// Diet filters combine as AND; allergen avoids hide dishes that list them.
/// Empty allergens stay visible — many dishes still lack upstream data.
public enum MenuFilterMatching {
    public static func matches(
        item: MenuItem,
        dietFilters: Set<String>,
        allergenAvoids: Set<String>
    ) -> Bool {
        let dietsOK = dietFilters.allSatisfy { filter in
            item.dietaryTags.contains { $0.caseInsensitiveCompare(filter) == .orderedSame }
        }
        guard dietsOK else { return false }
        guard !allergenAvoids.isEmpty else { return true }
        return !item.allergens.contains { allergen in
            allergenAvoids.contains { $0.caseInsensitiveCompare(allergen) == .orderedSame }
        }
    }

    /// Drop stations that have no remaining items after filtering.
    public static func filterStations(
        _ stations: [MenuStation],
        dietFilters: Set<String>,
        allergenAvoids: Set<String>
    ) -> [MenuStation] {
        guard !dietFilters.isEmpty || !allergenAvoids.isEmpty else { return stations }
        return stations.compactMap { station in
            let items = station.items.filter {
                matches(item: $0, dietFilters: dietFilters, allergenAvoids: allergenAvoids)
            }
            return items.isEmpty ? nil : MenuStation(name: station.name, items: items)
        }
    }
}
