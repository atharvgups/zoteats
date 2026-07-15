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
    /// Keyed by "\(hallID)|\(period)".
    private(set) var menus: [String: LoadState<DiningMenu>] = [:]

    init(service: DiningService = DiningService()) {
        self.service = service
    }

    func loadLocations() async {
        if locations.value == nil { locations = .loading }
        let result = await service.locations()
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
    private static let favoritesKey = "zoteats.favoriteDishNames"
    private static let dietFilterKey = "zoteats.dietFilter"

    /// Favorite dishes by name (dish IDs rotate daily; names are stable).
    var favoriteDishNames: Set<String> {
        didSet { UserDefaults.standard.set(Array(favoriteDishNames), forKey: Self.favoritesKey) }
    }

    /// Active dietary filter tag (e.g. "Vegan"), or nil for everything.
    var dietFilter: String? {
        didSet { UserDefaults.standard.set(dietFilter, forKey: Self.dietFilterKey) }
    }

    init() {
        favoriteDishNames = Set(UserDefaults.standard.stringArray(forKey: Self.favoritesKey) ?? [])
        dietFilter = UserDefaults.standard.string(forKey: Self.dietFilterKey)
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
