import Foundation

/// Hub-published Oasis stations and the UCI Serve-Up Kiosk copy.
///
/// MyDiningHub (`the-oasis-dining-hall`) lists stations as category children
/// with positions. The location page says guests can enjoy made-to-order
/// selections from Serve-Up Kiosks, including handcrafted pizzas and deli
/// sandwiches. Other Hub stations are not named as kiosks, so Eat labels
/// them grab and go. Names and ids come from Hub; this file does not invent
/// dishes or extra stations.
public enum OasisBoard: Sendable {
    public struct StationMeta: Equatable, Sendable {
        public let id: String
        public let name: String
        public let position: Int

        public init(id: String, name: String, position: Int) {
            self.id = id
            self.name = name
            self.position = position
        }
    }

    public struct PostedBoard: Equatable, Sendable {
        public let stationsByPeriod: [String: [MenuStation]]

        public init(stationsByPeriod: [String: [MenuStation]]) {
            self.stationsByPeriod = stationsByPeriod
        }

        /// Lunch and Dinner only. Hub also copies SKUs onto Brunch / All Day;
        /// Oasis does not serve those meals.
        public var availablePeriods: [String] {
            OasisBoard.servedPeriodNames.filter { period in
                !(stationsByPeriod[period] ?? []).isEmpty
            }
        }

        public func stations(for period: String) -> [MenuStation] {
            stationsByPeriod[period] ?? []
        }
    }

    /// Hub commerce category children as of the live Oasis page.
    public static let publishedStations: [StationMeta] = [
        StationMeta(id: "306552", name: "Main", position: 1),
        StationMeta(id: "306555", name: "Salad & Soup", position: 2),
        StationMeta(id: "306558", name: "Grill/Deli", position: 3),
        StationMeta(id: "306561", name: "Desserts", position: 4),
        StationMeta(id: "306564", name: "Pizza", position: 5),
        StationMeta(id: "306567", name: "Saute", position: 6),
    ]

    public static let servedPeriodNames = ["Lunch", "Dinner"]

    public static let kioskOrderOnlyLabel = "Kiosk order only"
    public static let grabAndGoLabel = "Grab and go"

    public static func directory(
        overlaying live: [StationMeta]
    ) -> [String: StationMeta] {
        var map: [String: StationMeta] = [:]
        for row in publishedStations {
            map[row.id] = row
        }
        for row in live {
            let id = row.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !name.isEmpty else { continue }
            map[id] = StationMeta(
                id: id,
                name: name,
                position: row.position > 0 ? row.position : (map[id]?.position ?? row.position)
            )
        }
        return map
    }

    /// UCI copy: made-to-order Serve-Up Kiosks, including handcrafted pizzas
    /// and deli sandwiches. Pizza and Grill/Deli match that. Other Hub Oasis
    /// stations are not named as kiosks, so Eat labels them grab and go.
    /// Do not invent extra kiosks.
    public static func serviceLabel(stationName: String) -> String? {
        let lowered = DiningService.collapsedStationName(stationName)
        guard !lowered.isEmpty else { return nil }
        if lowered.contains("pizza") || lowered.contains("deli") {
            return kioskOrderOnlyLabel
        }
        return grabAndGoLabel
    }

    public static func isHotLineStation(name: String) -> Bool {
        let lowered = DiningService.collapsedStationName(name)
        return lowered == "main" || lowered == "saute" || lowered == "sauté"
    }

    /// Intersect Hub station SKUs with one meal period. Drops empty boards,
    /// staples-only hot lines, and never invents dishes.
    public static func stationsForPeriod(
        periodSKUs: [String],
        stationSKUs: [(id: String, skus: [String])],
        directory: [String: StationMeta],
        products: [String: MenuItem]
    ) -> [MenuStation] {
        let periodSet = Set(periodSKUs.filter { !$0.isEmpty })
        guard !periodSet.isEmpty else { return [] }

        let grouped: [(meta: StationMeta, items: [MenuItem])]
        if stationSKUs.isEmpty {
            grouped = fallbackGroups(
                periodSet: periodSet,
                directory: directory,
                products: products
            )
        } else {
            grouped = stationSKUs.compactMap { row in
                let id = row.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let meta = directory[id] else { return nil }
                let items = uniqueItems(
                    skus: row.skus.filter { periodSet.contains($0) },
                    products: products,
                    stationID: id
                )
                return (meta, items)
            }
        }

        return grouped
            .compactMap { pair -> MenuStation? in
                let items = pair.items
                guard !items.isEmpty else { return nil }
                if isHotLineStation(name: pair.meta.name),
                   items.allSatisfy({ DiningService.isStationStaple($0.name) }) {
                    return nil
                }
                return MenuStation(
                    name: pair.meta.name,
                    items: items,
                    stationID: pair.meta.id,
                    serviceLabel: serviceLabel(stationName: pair.meta.name)
                )
            }
            .sorted { lhs, rhs in
                let left = directory[lhs.stationID ?? ""]?.position ?? .max
                let right = directory[rhs.stationID ?? ""]?.position ?? .max
                if left != right { return left < right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    public static func postedBoard(
        mealPeriodSKUs: [(name: String, skus: [String])],
        stationSKUs: [(id: String, skus: [String])],
        directory: [String: StationMeta],
        products: [String: MenuItem]
    ) -> PostedBoard {
        var map: [String: [MenuStation]] = [:]
        for period in mealPeriodSKUs {
            let name = period.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard servedPeriodNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
            else { continue }
            let canonical = servedPeriodNames.first { $0.caseInsensitiveCompare(name) == .orderedSame } ?? name
            let stations = stationsForPeriod(
                periodSKUs: period.skus,
                stationSKUs: stationSKUs,
                directory: directory,
                products: products
            )
            if !stations.isEmpty {
                map[canonical] = stations
            }
        }
        return PostedBoard(stationsByPeriod: map)
    }

    private static func fallbackGroups(
        periodSet: Set<String>,
        directory: [String: StationMeta],
        products: [String: MenuItem]
    ) -> [(meta: StationMeta, items: [MenuItem])] {
        var buckets: [String: [MenuItem]] = [:]
        for sku in periodSet {
            guard var item = products[sku] else { continue }
            let sid = item.stationID.flatMap { directory[$0] != nil ? $0 : nil }
                ?? directory.keys.first { key in
                    item.stationID == key
                }
            guard let sid, directory[sid] != nil else { continue }
            if item.stationID != sid {
                item = MenuItem(
                    id: item.id,
                    name: item.name,
                    description: item.description,
                    calories: item.calories,
                    servingSize: item.servingSize,
                    allergens: item.allergens,
                    dietaryTags: item.dietaryTags,
                    nutrition: item.nutrition,
                    stationID: sid
                )
            }
            buckets[sid, default: []].append(item)
        }
        return buckets.compactMap { sid, items in
            guard let meta = directory[sid] else { return nil }
            return (meta, uniqueItems(items: items, stationID: sid))
        }
    }

    private static func uniqueItems(
        skus: [String],
        products: [String: MenuItem],
        stationID: String
    ) -> [MenuItem] {
        uniqueItems(
            items: skus.compactMap { products[$0] },
            stationID: stationID
        )
    }

    private static func uniqueItems(items: [MenuItem], stationID: String) -> [MenuItem] {
        let tagged = items.map { item -> MenuItem in
            if item.stationID == stationID { return item }
            return MenuItem(
                id: item.id,
                name: item.name,
                description: item.description,
                calories: item.calories,
                servingSize: item.servingSize,
                allergens: item.allergens,
                dietaryTags: item.dietaryTags,
                nutrition: item.nutrition,
                stationID: stationID
            )
        }
        return DiningService.dedupeStationItems(tagged)
    }
}
