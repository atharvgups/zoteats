import Foundation

/// App Group disk for Home Screen widgets — the extension process does **not**
/// share the app’s in-memory `TTLCache`, so without this every glance waits on
/// the network (and WidgetKit keeps the system redacted placeholder until the
/// timeline finishes). The main app writes after each successful fetch; widgets
/// read first, then refresh.
public enum WidgetSnapshotStore {
    public static let diningLocationsKey = "zoteats.widget.diningLocations.v1"
    public static let diningMenusKey = "zoteats.widget.diningMenus.v1"
    public static let campusPlacesKey = "zoteats.widget.campusPlaces.v1"
    public static let busynessPlacesKey = "zoteats.widget.busynessPlaces.v1"
    public static let savedAtSuffix = ".savedAt"

    private static let io = NSLock()
    private static var suite: UserDefaults { SharedDefaults.suite }

    // MARK: - Dining

    public static func saveDiningLocations(_ locations: [DiningLocation]) {
        save(locations, key: diningLocationsKey)
    }

    public static func loadDiningLocations() -> [DiningLocation]? {
        load(key: diningLocationsKey)
    }

    /// Stable App Group key — primary pill (Breakfast/Lunch/Dinner), not Brunch.
    public static func diningMenuEntryKey(hall: String, period: String, dateISO: String) -> String {
        let pill = MealPeriodPill.canonical(period).lowercased()
        return "\(hall.lowercased())|\(pill)|\(dateISO)"
    }

    /// Persist a board the main app just loaded so Today's Menu / Favorites
    /// can paint without a cold extension network fetch.
    public static func saveDiningMenu(_ menu: DiningMenu) {
        io.lock()
        defer { io.unlock() }
        var all: [String: DiningMenu] = loadUnlocked(key: diningMenusKey) ?? [:]
        let key = diningMenuEntryKey(hall: menu.locationId, period: menu.period, dateISO: menu.date)
        all[key] = menu
        // Drop other days so the suite doesn't grow forever across rollovers.
        all = all.filter { entryKey, _ in
            entryKey.hasSuffix("|\(menu.date)") || entryKey == key
        }
        saveUnlocked(all, key: diningMenusKey)
    }

    public static func loadDiningMenu(
        hall: String,
        period: String,
        dateISO: String
    ) -> DiningMenu? {
        let key = diningMenuEntryKey(hall: hall, period: period, dateISO: dateISO)
        return loadDiningMenus()?[key]
    }

    public static func loadDiningMenus() -> [String: DiningMenu]? {
        load(key: diningMenusKey)
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

    /// Snapshot is from today's Irvine calendar day — safe to paint Eat / Campus.
    public static func savedOnCurrentIrvineDay(_ key: String, now: Date = .now) -> Bool {
        guard let saved = savedAt(for: key) else { return false }
        return UCITime.todayISO(now: saved) == UCITime.todayISO(now: now)
    }

    /// Instant Eat paint: last-known halls from this Irvine day, else nil.
    public static func loadDiningLocationsIfCurrentDay(now: Date = .now) -> [DiningLocation]? {
        guard savedOnCurrentIrvineDay(diningLocationsKey, now: now),
              let locations = loadDiningLocations(),
              !locations.isEmpty
        else { return nil }
        return locations
    }

    /// Today's saved boards (primary pills) — widgets can paint before any network.
    public static func loadDiningMenusIfCurrentDay(now: Date = .now) -> [DiningMenu] {
        guard savedOnCurrentIrvineDay(diningMenusKey, now: now),
              let all = loadDiningMenus()
        else { return [] }
        let today = UCITime.todayISO(now: now)
        return Array(all.values.filter { $0.date == today })
    }

    /// Instant Campus paint: last-known places from this Irvine day, else nil.
    public static func loadCampusPlacesIfCurrentDay(now: Date = .now) -> [CampusPlace]? {
        guard savedOnCurrentIrvineDay(campusPlacesKey, now: now),
              let places = loadCampusPlaces(),
              !places.isEmpty
        else { return nil }
        return places
    }

    /// Instant Study paint: last Waitz reading, even if a few minutes old.
    public static func loadBusynessPlacesIfPresent() -> [BusynessPoint]? {
        guard let places = loadBusynessPlaces(), !places.isEmpty else { return nil }
        return places
    }

    // MARK: - Codable helpers

    private static func save<T: Encodable>(_ value: T, key: String) {
        io.lock()
        defer { io.unlock() }
        saveUnlocked(value, key: key)
    }

    private static func load<T: Decodable>(key: String) -> T? {
        io.lock()
        defer { io.unlock() }
        return loadUnlocked(key: key)
    }

    private static func saveUnlocked<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        suite.set(data, forKey: key)
        suite.set(Date(), forKey: key + savedAtSuffix)
    }

    private static func loadUnlocked<T: Decodable>(key: String) -> T? {
        guard let data = suite.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// Clock-first widget timing — never “opens 67h 57m”.
/// Avoids `Text(timerInterval:)` which WidgetKit often redacts.
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

    /// Pacific wall clock, e.g. "7:15 AM".
    public static func clock(at date: Date) -> String {
        UCITime.format(minutes: UCITime.nowMinutes(now: date))
    }

    public static func closesLine(until end: Date, now: Date = .now) -> String {
        "until \(clock(at: end))"
    }

    public static func opensLine(until end: Date, now: Date = .now) -> String {
        let minutes = UCITime.nowMinutes(now: end)
        let time = UCITime.format(minutes: minutes)
        if isSameIrvineDay(end, now) {
            return "at \(time)"
        }
        if isNextIrvineDay(end, now) {
            return "tomorrow \(time)"
        }
        return "\(shortWeekday(end)) \(time)"
    }

    private static func isSameIrvineDay(_ date: Date, _ now: Date) -> Bool {
        UCITime.todayISO(now: date) == UCITime.todayISO(now: now)
    }

    private static func isNextIrvineDay(_ date: Date, _ now: Date) -> Bool {
        UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
            == UCITime.todayISO(now: date)
    }

    private static func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

/// Honest empty copy when the widget has no App Group snapshot and network failed.
public enum WidgetLoadEmptyCopy {
    public static let title = "Open Anteats to refresh"
    public static let detail = "Open Eat once so today’s menus show up here."
}
