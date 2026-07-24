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
    private let snapshots: SnapshotCache

    var locations: LoadState<[DiningLocation]> = .idle
    /// Keyed by "\(hallID)|\(period)|\(date-or-today)".
    private(set) var menus: [String: LoadState<DiningMenu>] = [:]
    /// True when this launch rendered from a disk snapshot (perf telemetry).
    private(set) var hydratedFromDisk = false

    init(service: DiningService = DiningService(), snapshots: SnapshotCache = .shared) {
        self.service = service
        self.snapshots = snapshots

        // Stale-while-revalidate: render the last-known data instantly on
        // launch; the .task refresh replaces it silently.
        if let saved = snapshots.load([DiningLocation].self, key: "dining.locations"), !saved.isEmpty {
            locations = .loaded(saved)
            hydratedFromDisk = true
        }
        let today = UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
        if let saved = snapshots.load(MenusSnapshot.self, key: "dining.menus"), saved.dateISO == today {
            for (key, menu) in saved.menus {
                menus[key] = .loaded(menu)
            }
        }
    }

    func loadLocations() async {
        if locations.value == nil { locations = .loading }
        let result = await service.locations()
        // The service degrades per-hall; treat "no data at all" as an error state
        // — but never clobber a good snapshot with an outage.
        if result.allSatisfy({ $0.availablePeriods.isEmpty && $0.todayHours == nil }) {
            if locations.value == nil {
                locations = .failed("UCI Dining isn't reachable right now.")
            }
        } else {
            locations = .loaded(result)
            snapshots.save(result, key: "dining.locations")
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
            persistTodayMenus()
        } catch {
            // Keep stale menu visible through a refresh failure.
            if menus[key]?.value == nil {
                menus[key] = .failed(error.localizedDescription)
            }
        }
    }

    /// Warm every period of a hall (service TTL cache dedupes network work),
    /// so switching meal periods is instant. Network fan-out happens off-actor;
    /// results apply back on the main actor.
    func prefetchMenus(hall: String, periods: [String]) async {
        let service = self.service
        let targets = periods.prefix(6).filter { menus["\(hall)|\($0)|today"]?.value == nil }
        guard !targets.isEmpty else { return }

        let fetched = await withTaskGroup(of: (String, DiningMenu?).self) { group in
            for period in targets {
                group.addTask {
                    (period, try? await service.menu(for: hall, period: period))
                }
            }
            var collected: [(String, DiningMenu)] = []
            for await (period, menu) in group {
                if let menu { collected.append((period, menu)) }
            }
            return collected
        }

        for (period, menu) in fetched {
            let key = "\(hall)|\(period)|today"
            if menus[key]?.value == nil {
                menus[key] = .loaded(menu)
            }
        }
        if !fetched.isEmpty {
            persistTodayMenus()
        }
    }

    private func persistTodayMenus() {
        let today = UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
        var payload: [String: DiningMenu] = [:]
        for (key, state) in menus where key.hasSuffix("|today") {
            if let menu = state.value {
                payload[key] = menu
            }
        }
        snapshots.save(MenusSnapshot(dateISO: today, menus: payload), key: "dining.menus")
    }
}

@MainActor
@Observable
final class GymStore {
    private let service: GymService
    private let snapshots: SnapshotCache

    var status: LoadState<GymStatus> = .idle
    private(set) var hydratedFromDisk = false

    init(service: GymService = GymService(), snapshots: SnapshotCache = .shared) {
        self.service = service
        self.snapshots = snapshots
        if let saved = snapshots.load(GymStatus.self, key: "gym.status") {
            status = .loaded(saved)
            hydratedFromDisk = true
        }
    }

    func load() async {
        if status.value == nil { status = .loading }
        let result = await service.status()
        status = .loaded(result)
        snapshots.save(result, key: "gym.status")
    }
}

@MainActor
@Observable
final class CampusStore {
    private let service: CampusService
    private let snapshots: SnapshotCache

    var places: LoadState<[CampusPlace]> = .idle
    /// Keyed by place id.
    private(set) var menus: [String: LoadState<[MenuStation]>] = [:]
    private(set) var hydratedFromDisk = false

    init(service: CampusService = CampusService(), snapshots: SnapshotCache = .shared) {
        self.service = service
        self.snapshots = snapshots
        if let saved = snapshots.load([CampusPlace].self, key: "campus.places"), !saved.isEmpty {
            places = .loaded(saved)
            hydratedFromDisk = true
        }
    }

    func loadPlaces() async {
        if places.value == nil { places = .loading }
        do {
            let result = try await service.places()
            places = .loaded(result)
            snapshots.save(result, key: "campus.places")
        } catch {
            // Keep the stale list through a refresh failure.
            if places.value == nil {
                places = .failed(error.localizedDescription)
            }
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
    private let snapshots: SnapshotCache

    var facilities: LoadState<[BusynessPoint]> = .idle
    private(set) var hydratedFromDisk = false

    init(service: BusynessService = BusynessService(), snapshots: SnapshotCache = .shared) {
        self.service = service
        self.snapshots = snapshots
        // Stale occupancy still renders honestly: UpdatedAgoText shows its true age.
        if let saved = snapshots.load([BusynessPoint].self, key: "busyness.facilities"), !saved.isEmpty {
            facilities = .loaded(saved)
            hydratedFromDisk = true
        }
    }

    func load() async {
        if facilities.value == nil { facilities = .loading }
        do {
            let result = try await service.all()
            facilities = .loaded(result)
            snapshots.save(result, key: "busyness.facilities")
        } catch {
            // Keep the stale list through a refresh failure.
            if facilities.value == nil {
                facilities = .failed(error.localizedDescription)
            }
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
