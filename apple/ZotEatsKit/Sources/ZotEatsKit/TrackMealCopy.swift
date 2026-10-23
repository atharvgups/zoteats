import Foundation

/// Favorites on the live board — used if a meal is added to My Plate in bulk.
public enum TrackMealPlateItems: Sendable {
    public static func favorites(
        from stations: [MenuStation],
        favoriteNames: Set<String>
    ) -> [MenuItem] {
        FavoritesOnMenuPick.servedItems(favorites: favoriteNames, stations: stations)
    }
}
