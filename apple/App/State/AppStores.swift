import Foundation
import Observation
import SwiftUI
import ZotEatsKit

// Observable stores bridging ZotEatsKit services to SwiftUI.
// Services already cache aggressively (TTLCache), so stores can refetch freely.

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
@Observable
final class DiningStore {
    private let service: DiningService

    var locations: LoadState<[DiningLocation]> = .idle
    /// Inclusive ISO window the feed currently publishes — clamps the day strip.
    private(set) var publishedDateRange: DiningService.PublishedDateRange?
    /// Keyed by "\(hallID)|\(period)".
    private(set) var menus: [String: LoadState<DiningMenu>] = [:]

    init(service: DiningService = DiningService()) {
        self.service = service
    }

    func loadLocations() async {
        if locations.value == nil { locations = .loading }
        async let range = service.publishedDateRange()
        let result = await service.locations()
        publishedDateRange = await range
        // The service degrades per-hall; treat "no data at all" as an error state.
        if result.allSatisfy({ $0.availablePeriods.isEmpty && $0.todayHours == nil }) {
            locations = .failed("UCI Dining isn't reachable right now.")
        } else {
            locations = .loaded(result)
        }
    }

    func menuState(hall: String, period: String, date: String? = nil) -> LoadState<DiningMenu> {
        menus["\(hall)|\(period)|\(date ?? "today")"] ?? .idle
    }

    func loadMenu(hall: String, period: String, date: String? = nil) async {
        let key = "\(hall)|\(period)|\(date ?? "today")"
        if menus[key]?.value == nil { menus[key] = .loading }
        do {
            menus[key] = .loaded(try await service.menu(for: hall, period: period, date: date))
        } catch {
            menus[key] = .failed(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class GymStore {
    private let service: GymService

    var status: LoadState<GymStatus> = .idle

    init(service: GymService = GymService()) {
        self.service = service
    }

    func load() async {
        if status.value == nil { status = .loading }
        status = .loaded(await service.status())
    }
}

@MainActor
@Observable
final class CampusStore {
    private let service: CampusService

    var places: LoadState<[CampusPlace]> = .idle
    /// Keyed by place id.
    private(set) var menus: [String: LoadState<[MenuStation]>] = [:]

    init(service: CampusService = CampusService()) {
        self.service = service
    }

    func loadPlaces() async {
        if places.value == nil { places = .loading }
        do {
            places = .loaded(try await service.places())
        } catch {
            places = .failed(error.localizedDescription)
        }
    }

    func menuState(for placeID: String) -> LoadState<[MenuStation]> {
        menus[placeID] ?? .idle
    }

    func loadMenu(for placeID: String) async {
        if menus[placeID]?.value == nil { menus[placeID] = .loading }
        do {
            menus[placeID] = .loaded(try await service.menu(for: placeID))
        } catch {
            menus[placeID] = .failed(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class BusynessStore {
    private let service: BusynessService

    var facilities: LoadState<[BusynessPoint]> = .idle

    init(service: BusynessService = BusynessService()) {
        self.service = service
    }

    func load() async {
        if facilities.value == nil { facilities = .loading }
        do {
            facilities = .loaded(try await service.all())
        } catch {
            facilities = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Preferences (favorites + dietary filter), persisted in UserDefaults

@MainActor
@Observable
final class Preferences {
    private static let legacyDietFilterKey = "zoteats.dietFilter"

    /// Favorite dishes by name (IDs rotate daily; names are stable).
    /// Mirrored into the App Group so Today's Menu widgets can pin them.
    var favoriteDishNames: Set<String> {
        didSet {
            SharedDefaults.setFavoriteDishNames(Array(favoriteDishNames).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Active dietary filter tags (AND). Empty = show everything.
    /// Mirrored into the App Group so Today's Menu honors Eat Filters.
    var dietFilters: Set<String> {
        didSet {
            SharedDefaults.setDietFilters(Array(dietFilters).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Allergens to hide (OR). A dish listing any avoided allergen is filtered out.
    var allergenAvoids: Set<String> {
        didSet {
            SharedDefaults.setAllergenAvoids(Array(allergenAvoids).sorted())
            WidgetReloader.reloadTodaysMenu()
        }
    }

    /// Convenience for single-filter callers (campus sheet, etc.).
    var dietFilter: String? {
        get { dietFilters.sorted().first }
        set {
            if let newValue {
                dietFilters = [newValue]
            } else {
                dietFilters = []
            }
        }
    }

    var hasActiveMenuFilters: Bool {
        !dietFilters.isEmpty || !allergenAvoids.isEmpty
    }

    init() {
        favoriteDishNames = Set(SharedDefaults.favoriteDishNames())
        let storedDiets = SharedDefaults.dietFilters()
        if !storedDiets.isEmpty {
            dietFilters = Set(storedDiets)
        } else if let legacy = UserDefaults.standard.string(forKey: Self.legacyDietFilterKey) {
            dietFilters = [legacy]
            UserDefaults.standard.removeObject(forKey: Self.legacyDietFilterKey)
        } else {
            dietFilters = []
        }
        allergenAvoids = Set(SharedDefaults.allergenAvoids())
        // Init assignments skip didSet — mirror into the App Group for widgets.
        SharedDefaults.setDietFilters(Array(dietFilters).sorted())
        SharedDefaults.setAllergenAvoids(Array(allergenAvoids).sorted())
    }

    func clearMenuFilters() {
        dietFilters = []
        allergenAvoids = []
    }

    /// Re-read Eat Filters from the App Group after the Today’s Menu widget
    /// (or another process) clears or changes them while we were suspended.
    func reloadMenuFiltersFromSharedDefaults() {
        let diets = Set(SharedDefaults.dietFilters())
        let allergens = Set(SharedDefaults.allergenAvoids())
        if diets != dietFilters {
            dietFilters = diets
        }
        if allergens != allergenAvoids {
            allergenAvoids = allergens
        }
    }

    func matchesMenuFilters(_ item: MenuItem) -> Bool {
        MenuFilterMatching.matches(
            item: item,
            dietFilters: dietFilters,
            allergenAvoids: allergenAvoids
        )
    }

    func toggleFavorite(_ dishName: String) {
        if favoriteDishNames.contains(dishName) {
            favoriteDishNames.remove(dishName)
        } else {
            favoriteDishNames.insert(dishName)
        }
        Haptics.soft()
    }

    func isFavorite(_ dishName: String) -> Bool {
        favoriteDishNames.contains(dishName)
    }
}
