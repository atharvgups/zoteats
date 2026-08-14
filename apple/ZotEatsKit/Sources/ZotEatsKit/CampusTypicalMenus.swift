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
        case choolaah
        case wushiland
        case tortillaFresca
        case anthillPub
        case greensToGo
        case bAndF
        case javaCity
        case halalShack

        var stations: [MenuStation] {
            switch self {
            case .starbucks: return Self.starbucksStations
            case .pandaExpress: return Self.pandaStations
            case .subway: return Self.subwayStations
            case .jamba: return Self.jambaStations
            case .zotNGo: return Self.zotNGoStations
            case .einstein: return Self.einsteinStations
            case .panera: return Self.paneraStations
            case .choolaah: return Self.choolaahStations
            case .wushiland: return Self.wushilandStations
            case .tortillaFresca: return Self.tortillaFrescaStations
            case .anthillPub: return Self.anthillPubStations
            case .greensToGo: return Self.greensToGoStations
            case .bAndF: return Self.bAndFStations
            case .javaCity: return Self.javaCityStations
            case .halalShack: return Self.halalShackStations
            }
        }

        private static let starbucksStations: [MenuStation] = [
            station("Espresso drinks", [
                item("Caffè Latte"), item("Cappuccino"), item("Americano"),
                item("Flat White"), item("Espresso"), item("Caffè Mocha"),
            ]),
            station("Brewed & iced", [
                item("Pike Place Roast"), item("Cold Brew"),
                item("Iced Coffee"), item("Iced Tea"),
            ]),
            station("Other", [
                item("Hot Chocolate"),
                item("Refreshers (ask barista)"),
                item("Bakery case items"),
            ]),
        ]

        private static let pandaStations: [MenuStation] = [
            station("Entrees", [
                item("Orange Chicken"), item("Beijing Beef"), item("Broccoli Beef"),
                item("Kung Pao Chicken"), item("Grilled Teriyaki Chicken"),
                item("Honey Walnut Shrimp"),
            ]),
            station("Sides", [
                item("Fried Rice"), item("Chow Mein"),
                item("Super Greens", tags: ["Vegan", "Vegetarian"]),
                item("White Steamed Rice", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Appetizers", [
                item("Chicken Egg Roll"),
                item("Veggie Spring Roll", tags: ["Vegetarian"]),
                item("Cream Cheese Rangoons"),
            ]),
        ]

        private static let subwayStations: [MenuStation] = [
            station("Sandwiches", [
                item("Italian B.M.T."), item("Turkey Breast"), item("Tuna"),
                item("Veggie Delite", tags: ["Vegan", "Vegetarian"]),
                item("Spicy Italian"), item("Meatball Marinara"),
                item("Chicken Teriyaki"),
            ]),
            station("Extras", [
                item("Cookies"), item("Chips"), item("Fountain drink"),
            ]),
        ]

        private static let jambaStations: [MenuStation] = [
            station("Classic smoothies", [
                item("Strawberries Wild"), item("Orange Dream Machine"),
                item("Mango-a-go-go"), item("Caribbean Passion"), item("Razzmatazz"),
            ]),
            station("Other", [
                item("Bowls (ask for today’s list)"),
                item("Fresh-squeezed juices"),
            ]),
        ]

        private static let zotNGoStations: [MenuStation] = [
            station("Grab & go", [
                item("Breakfast sandwiches / burritos"), item("Fresh wraps"),
                item("Sushi packs"), item("Prepared salads"), item("Pastries"),
            ]),
            station("Market", [
                item("Coffee (50¢ off with reusable cup)"), item("Cold drinks"),
                item("Snacks"), item("Fresh produce", tags: ["Vegan", "Vegetarian"]),
                item("Ice cream / frozen meals"), item("Household essentials"),
            ]),
        ]

        private static let einsteinStations: [MenuStation] = [
            station("Bagels", [
                item("Plain", tags: ["Vegetarian"]),
                item("Everything", tags: ["Vegetarian"]),
                item("Sesame", tags: ["Vegetarian"]),
                item("Cinnamon Raisin", tags: ["Vegetarian"]),
                item("Asiago", tags: ["Vegetarian"]),
            ]),
            station("Spreads & sandwiches", [
                item("Shmear (ask flavors)"),
                item("Breakfast sandwiches"),
                item("Coffee"),
            ]),
        ]

        private static let paneraStations: [MenuStation] = [
            station("Bakery & cafe", [
                item("Bagels & pastries"), item("Soups (rotating)"),
                item("Salads"), item("Sandwiches / paninis"),
                item("Coffee & fountain drinks"),
            ]),
        ]

        private static let choolaahStations: [MenuStation] = [
            station("Bowls & plates", [
                item("Build-your-own Indian bowl"),
                item("Chicken tikka"),
                item("Paneer", tags: ["Vegetarian"]),
                item("Chana masala", tags: ["Vegan", "Vegetarian"]),
                item("Basmati rice", tags: ["Vegan", "Vegetarian"]),
                item("Naan"),
            ]),
            station("Sides", [
                item("Samosas"), item("Raita"), item("Chutneys"),
            ]),
        ]

        private static let wushilandStations: [MenuStation] = [
            station("Boba & tea", [
                item("Classic milk tea"), item("Brown sugar boba"),
                item("Fruit teas"), item("Slush / snow"),
                item("Add boba / toppings"),
            ]),
        ]

        private static let tortillaFrescaStations: [MenuStation] = [
            station("Mexican grill", [
                item("Burritos"), item("Tacos"), item("Quesadillas"),
                item("Nachos"), item("Rice & beans", tags: ["Vegetarian"]),
                item("Chips & salsa", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let anthillPubStations: [MenuStation] = [
            station("Pub fare", [
                item("Burgers"), item("Sandwiches"), item("Fries"),
                item("Salads"), item("Wings / sharables"),
                item("Soft drinks"),
            ]),
        ]

        private static let greensToGoStations: [MenuStation] = [
            station("Salads & bowls", [
                item("Build-your-own salad", tags: ["Vegetarian"]),
                item("Grain bowls"), item("Wraps"),
                item("Soups (rotating)"),
                item("Fruit cups", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let bAndFStations: [MenuStation] = [
            station("Burgers & fries", [
                item("Classic burger"), item("Chicken sandwich"),
                item("Veggie burger", tags: ["Vegetarian"]),
                item("Fries"), item("Onion rings"), item("Shakes"),
            ]),
        ]

        private static let javaCityStations: [MenuStation] = [
            station("Coffee & cafe", [
                item("Brewed coffee"), item("Espresso drinks"),
                item("Iced coffee / tea"), item("Pastries"),
                item("Bottled drinks"),
            ]),
        ]

        private static let halalShackStations: [MenuStation] = [
            station("Plates", [
                item("Chicken over rice", tags: ["Halal"]),
                item("Lamb over rice", tags: ["Halal"]),
                item("Combo over rice", tags: ["Halal"]),
                item("Falafel over rice", tags: ["Halal", "Vegan", "Vegetarian"]),
            ]),
            station("Wraps & sandwiches", [
                item("Chicken gyro", tags: ["Halal"]),
                item("Lamb gyro", tags: ["Halal"]),
                item("Falafel wrap", tags: ["Halal", "Vegan", "Vegetarian"]),
                item("Chicken sandwich", tags: ["Halal"]),
            ]),
            station("Sides & extras", [
                item("White sauce"), item("Hot sauce"),
                item("Side salad", tags: ["Vegan", "Vegetarian"]),
                item("Fountain drink"),
            ]),
        ]

        private static func item(_ name: String, tags: [String] = []) -> (String, [String]) {
            (name, tags)
        }

        private static func station(
            _ name: String,
            _ items: [(String, [String])]
        ) -> MenuStation {
            MenuStation(
                name: name,
                items: items.map { name, tags in
                    MenuItem(
                        id: "typical:\(name.lowercased())",
                        name: name,
                        description: nil,
                        calories: nil,
                        servingSize: nil,
                        allergens: [],
                        dietaryTags: tags
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
        if hay.contains("choolaah") { return .choolaah }
        if hay.contains("wushiland") { return .wushiland }
        if hay.contains("tortilla") { return .tortillaFresca }
        if hay.contains("anthill") { return .anthillPub }
        if hay.contains("greens-to-go") || hay.contains("greens to go") {
            return .greensToGo
        }
        // B+F / B & F / BF at Phoenix — avoid matching random "b" alone.
        if hay.contains("b-f-") || hay.contains("b-f-and") || hay.contains("b+f")
            || name.contains("b+f") || name.contains("b & f") || name.contains("b and f") {
            return .bAndF
        }
        if hay.contains("java-city") || hay.contains("java city") { return .javaCity }
        if hay.contains("halal-shack") || hay.contains("halal shack") { return .halalShack }
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
