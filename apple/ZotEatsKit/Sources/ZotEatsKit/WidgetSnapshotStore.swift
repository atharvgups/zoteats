import Foundation

/// App Group disk for Home Screen widgets — the extension process does **not**
/// share the app’s in-memory `TTLCache`, so without this every glance waits on
/// the network (and WidgetKit keeps the system redacted placeholder until the
/// timeline finishes). The main app writes after each successful fetch; widgets
/// read first, then refresh.
public enum WidgetSnapshotStore {
    public static let diningLocationsKey = "zoteats.widget.diningLocations.v1"
    public static let campusPlacesKey = "zoteats.widget.campusPlaces.v1"
    public static let busynessPlacesKey = "zoteats.widget.busynessPlaces.v1"
    public static let savedAtSuffix = ".savedAt"

    private static var suite: UserDefaults { SharedDefaults.suite }

    // MARK: - Dining

    public static func saveDiningLocations(_ locations: [DiningLocation]) {
        save(locations, key: diningLocationsKey)
    }

    public static func loadDiningLocations() -> [DiningLocation]? {
        load(key: diningLocationsKey)
    }

    // MARK: - Campus

    public static func saveCampusPlaces(_ places: [CampusPlace]) {
        save(places, key: campusPlacesKey)
    }

    public static func loadCampusPlaces() -> [CampusPlace]? {
        load(key: campusPlacesKey)
    }

    // MARK: - Study / Waitz

    public static func saveBusynessPlaces(_ places: [BusynessPoint]) {
        save(places, key: busynessPlacesKey)
    }

    public static func loadBusynessPlaces() -> [BusynessPoint]? {
        load(key: busynessPlacesKey)
    }

    public static func savedAt(for key: String) -> Date? {
        suite.object(forKey: key + savedAtSuffix) as? Date
    }

    // MARK: - Codable helpers

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        suite.set(data, forKey: key)
        suite.set(Date(), forKey: key + savedAtSuffix)
    }

    private static func load<T: Decodable>(key: String) -> T? {
        guard let data = suite.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Static countdown labels for Home Screen widgets — avoids `Text(timerInterval:)`
/// which WidgetKit often treats as privacy-sensitive and can leave the whole
/// glance stuck on redacted placeholder bars.
public enum WidgetCountdownCopy {
    public static func short(until end: Date, now: Date = .now) -> String {
        let secs = max(0, Int(end.timeIntervalSince(now)))
        let minutes = secs / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let rem = minutes % 60
            return rem == 0 ? "\(hours)h" : "\(hours)h \(rem)m"
        }
        if minutes > 0 { return "\(minutes)m" }
        return "\(max(secs, 1))s"
    }

    public static func closesLine(until end: Date, now: Date = .now) -> String {
        "closes \(short(until: end, now: now))"
    }

    public static func opensLine(until end: Date, now: Date = .now) -> String {
        "opens \(short(until: end, now: now))"
    }
}

/// Honest empty copy when the widget has no App Group snapshot and network failed.
public enum WidgetLoadEmptyCopy {
    public static let title = "Open Anteats to refresh"
    public static let detail = "Menus load in the app, then show up here."
}
