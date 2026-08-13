import Foundation

/// Honest **typical** campus retail menus when Dining Hub has no live board.
/// Never labeled as “today’s live menu” — UI shows the disclaimer station.
public enum CampusTypicalMenus {
    public static let bannerStationName = "Typical menu"
    public static let disclaimer =
        "Not today’s live Dining Hub board — common items for this brand. Availability and prices vary."

    /// Source note for Zot N Go (public Dining Hub location blurbs + campus grab‑and‑go).
    public static let zotNGoSourceNote =
        "Assortment from UCI Dining Hub location copy (grab‑and‑go / convenience)."

    public static func isTypical(_ stations: [MenuStation]) -> Bool {
        stations.contains { $0.name == bannerStationName }
    }

    /// Fallback stations when live Hub menu is empty. `nil` = no typical pack.
    public static func stations(forPlaceID placeID: String, placeName: String) -> [MenuStation]? {
        guard let kind = kind(forPlaceID: placeID, placeName: placeName) else { return nil }
        var out = [bannerStation(for: kind)]
        out.append(contentsOf: kind.stations)
        return out
    }

    // MARK: - Matching

    public enum Kind: String, Equatable, Sendable {
        case starbucks
        case pandaExpress
        case subway
        case jamba
        case zotNGo
        case einstein
        case panera

        var stations: [MenuStation] {
            switch self {
            case .starbucks: return Self.starbucksStations
            case .pandaExpress: return Self.pandaStations
            case .subway: return Self.subwayStations
            case .jamba: return Self.jambaStations
            case .zotNGo: return Self.zotNGoStations
            case .einstein: return Self.einsteinStations
            case .panera: return Self.paneraStations
            }
        }

        private static let starbucksStations: [MenuStation] = [
            station("Espresso drinks", [
                "Caffè Latte", "Cappuccino", "Americano", "Flat White",
                "Espresso", "Caffè Mocha",
            ]),
            station("Brewed & iced", [
                "Pike Place Roast", "Cold Brew", "Iced Coffee", "Iced Tea",
            ]),
            station("Other", [
                "Hot Chocolate", "Refreshers (ask barista)", "Bakery case items",
            ]),
        ]

        private static let pandaStations: [MenuStation] = [
            station("Entrees", [
                "Orange Chicken", "Beijing Beef", "Broccoli Beef",
                "Kung Pao Chicken", "Grilled Teriyaki Chicken", "Honey Walnut Shrimp",
            ]),
            station("Sides", [
                "Fried Rice", "Chow Mein", "Super Greens", "White Steamed Rice",
            ]),
            station("Appetizers", [
                "Chicken Egg Roll", "Veggie Spring Roll", "Cream Cheese Rangoons",
            ]),
        ]

        private static let subwayStations: [MenuStation] = [
            station("Sandwiches", [
                "Italian B.M.T.", "Turkey Breast", "Tuna", "Veggie Delite",
                "Spicy Italian", "Meatball Marinara", "Chicken Teriyaki",
            ]),
            station("Extras", [
                "Cookies", "Chips", "Fountain drink",
            ]),
        ]

        private static let jambaStations: [MenuStation] = [
            station("Classic smoothies", [
                "Strawberries Wild", "Orange Dream Machine", "Mango-a-go-go",
                "Caribbean Passion", "Razzmatazz",
            ]),
            station("Other", [
                "Bowls (ask for today’s list)", "Fresh-squeezed juices",
            ]),
        ]

        private static let zotNGoStations: [MenuStation] = [
            station("Grab & go", [
                "Breakfast sandwiches / burritos", "Fresh wraps", "Sushi packs",
                "Prepared salads", "Pastries",
            ]),
            station("Market", [
                "Coffee (50¢ off with reusable cup)", "Cold drinks", "Snacks",
                "Fresh produce", "Ice cream / frozen meals", "Household essentials",
            ]),
        ]

        private static let einsteinStations: [MenuStation] = [
            station("Bagels", [
                "Plain", "Everything", "Sesame", "Cinnamon Raisin", "Asiago",
            ]),
            station("Spreads & sandwiches", [
                "Shmear (ask flavors)", "Breakfast sandwiches", "Coffee",
            ]),
        ]

        private static let paneraStations: [MenuStation] = [
            station("Bakery & cafe", [
                "Bagels & pastries", "Soups (rotating)", "Salads",
                "Sandwiches / paninis", "Coffee & fountain drinks",
            ]),
        ]

        private static func station(_ name: String, _ items: [String]) -> MenuStation {
            MenuStation(
                name: name,
                items: items.map {
                    MenuItem(
                        id: "typical:\($0.lowercased())",
                        name: $0,
                        description: nil,
                        calories: nil,
                        servingSize: nil,
                        allergens: [],
                        dietaryTags: []
                    )
                }
            )
        }
    }

    public static func kind(forPlaceID placeID: String, placeName: String) -> Kind? {
        let id = placeID.lowercased()
        let name = placeName.lowercased()
        let hay = id + " " + name
        if hay.contains("starbucks") { return .starbucks }
        if hay.contains("panda") { return .pandaExpress }
        if hay.contains("subway") { return .subway }
        if hay.contains("jamba") { return .jamba }
        if hay.contains("zot-n-go") || hay.contains("zot n go") { return .zotNGo }
        if hay.contains("einstein") { return .einstein }
        if hay.contains("panera") { return .panera }
        return nil
    }

    private static func bannerStation(for kind: Kind) -> MenuStation {
        let note: String
        switch kind {
        case .zotNGo:
            note = "\(disclaimer) \(zotNGoSourceNote)"
        default:
            note = disclaimer
        }
        return MenuStation(
            name: bannerStationName,
            items: [
                MenuItem(
                    id: "typical:disclaimer:\(kind.rawValue)",
                    name: note,
                    description: nil,
                    calories: nil,
                    servingSize: nil,
                    allergens: [],
                    dietaryTags: []
                ),
            ]
        )
    }
}
