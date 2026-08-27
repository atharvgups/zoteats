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
        case greenRoom
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
            case .greenRoom: return Self.greenRoomStations
            case .halalShack: return Self.halalShackStations
            }
        }

        private static let starbucksStations: [MenuStation] = [
            station("Espresso drinks", [
                item("Caffè Latte", tags: ["Vegetarian"]),
                item("Cappuccino", tags: ["Vegetarian"]),
                item("Americano", tags: ["Vegan", "Vegetarian"]),
                item("Flat White", tags: ["Vegetarian"]),
                item("Espresso", tags: ["Vegan", "Vegetarian"]),
                item("Caffè Mocha", tags: ["Vegetarian"]),
            ]),
            station("Brewed & iced", [
                item("Pike Place Roast", tags: ["Vegan", "Vegetarian"]),
                item("Cold Brew", tags: ["Vegan", "Vegetarian"]),
                item("Iced Coffee", tags: ["Vegan", "Vegetarian"]),
                item("Iced Tea", tags: ["Vegan", "Vegetarian"]),
                item("Starbucks Refreshers", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Blended & bakery", [
                item("Frappuccino (ask flavors)", tags: ["Vegetarian"]),
                item("Hot Chocolate", tags: ["Vegetarian"]),
                item("Breakfast sandwich"),
                item("Bakery case (pastries / cake pops)", tags: ["Vegetarian"]),
            ]),
        ]

        private static let pandaStations: [MenuStation] = [
            station("Entrees", [
                item("Orange Chicken"), item("Beijing Beef"), item("Broccoli Beef"),
                item("Kung Pao Chicken"), item("Grilled Teriyaki Chicken"),
                item("Honey Walnut Shrimp"), item("Mushroom Chicken"),
                item("Black Pepper Angus Steak"),
            ]),
            station("Sides", [
                item("Fried Rice"), item("Chow Mein"),
                item("Super Greens", tags: ["Vegan", "Vegetarian"]),
                item("White Steamed Rice", tags: ["Vegan", "Vegetarian"]),
                item("Brown Steamed Rice", tags: ["Vegan", "Vegetarian"]),
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
                item("Chicken Teriyaki"), item("Steak & Cheese"),
            ]),
            station("Salads & wraps", [
                item("Oven-Roasted Turkey Salad"),
                item("Veggie Delite Salad", tags: ["Vegan", "Vegetarian"]),
                item("Chicken & Bacon Ranch Wrap"),
                item("Veggie Wrap", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Extras", [
                item("Cookies"), item("Chips"), item("Fountain drink"),
            ]),
        ]

        private static let jambaStations: [MenuStation] = [
            station("Classic smoothies", [
                item("Strawberries Wild", tags: ["Vegetarian"]),
                item("Orange Dream Machine", tags: ["Vegetarian"]),
                item("Mango-a-go-go", tags: ["Vegan", "Vegetarian"]),
                item("Caribbean Passion", tags: ["Vegan", "Vegetarian"]),
                item("Razzmatazz", tags: ["Vegetarian"]),
            ]),
            station("Bowls", [
                item("Acai Prima Bowl", tags: ["Vegetarian"]),
                item("Chunky Strawberry Bowl", tags: ["Vegetarian"]),
                item("Pitaya Island Bowl", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Juices & extras", [
                item("Fresh-squeezed juices", tags: ["Vegan", "Vegetarian"]),
                item("Boosts / energy shots"),
            ]),
        ]

        private static let zotNGoStations: [MenuStation] = [
            station("Grab & go", [
                item("Breakfast sandwiches / burritos"),
                item("Fresh wraps"),
                item("Veggie wrap", tags: ["Vegetarian"]),
                item("Sushi packs"),
                item("Prepared salads", tags: ["Vegetarian"]),
                item("Yogurt / parfait", tags: ["Vegetarian"]),
                item("Pastries"),
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
                item("Blueberry", tags: ["Vegetarian"]),
            ]),
            station("Spreads & sandwiches", [
                item("Plain shmear", tags: ["Vegetarian"]),
                item("Garden veggie shmear", tags: ["Vegetarian"]),
                item("Nova lox"),
                item("Ham & Swiss"),
                item("Bacon, egg & cheese"),
                item("Avocado smash", tags: ["Vegetarian"]),
            ]),
            station("Drinks", [
                item("Fresh-brewed coffee", tags: ["Vegan", "Vegetarian"]),
                item("Latte", tags: ["Vegetarian"]),
                item("Cold brew", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let paneraStations: [MenuStation] = [
            station("Soups & mac", [
                item("Broccoli Cheddar", tags: ["Vegetarian"]),
                item("Chicken noodle"),
                item("Tomato basil", tags: ["Vegetarian"]),
                item("Mac & cheese", tags: ["Vegetarian"]),
            ]),
            station("Salads & sandwiches", [
                item("Fuji Apple salad", tags: ["Vegetarian"]),
                item("Green goddess cobb"),
                item("Chipotle chicken avocado melt"),
                item("Mediterranean veggie", tags: ["Vegetarian"]),
                item("Bacon turkey bravo"),
            ]),
            station("Bakery & drinks", [
                item("Bagel", tags: ["Vegetarian"]),
                item("Pastry case", tags: ["Vegetarian"]),
                item("Coffee", tags: ["Vegan", "Vegetarian"]),
                item("Fountain drink"),
            ]),
        ]

        private static let choolaahStations: [MenuStation] = [
            station("Bowls & plates", [
                item("Build-your-own Indian bowl"),
                item("Chicken tikka"),
                item("Chicken tikka masala"),
                item("Saag paneer", tags: ["Vegetarian"]),
                item("Chana masala", tags: ["Vegan", "Vegetarian"]),
                item("Basmati rice", tags: ["Vegan", "Vegetarian"]),
                item("Garlic naan"),
            ]),
            station("Sides", [
                item("Samosas", tags: ["Vegetarian"]),
                item("Raita", tags: ["Vegetarian"]),
                item("Mango chutney", tags: ["Vegan", "Vegetarian"]),
                item("Mint chutney", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let wushilandStations: [MenuStation] = [
            station("Milk teas", [
                item("Classic milk tea", tags: ["Vegetarian"]),
                item("Brown sugar pearl milk tea", tags: ["Vegetarian"]),
                item("Oolong milk tea", tags: ["Vegetarian"]),
                item("Wintermelon milk tea", tags: ["Vegetarian"]),
            ]),
            station("Fruit teas & snow", [
                item("Mango green tea", tags: ["Vegan", "Vegetarian"]),
                item("Passion fruit green tea", tags: ["Vegan", "Vegetarian"]),
                item("Lychee black tea", tags: ["Vegan", "Vegetarian"]),
                item("Snow / slush"),
            ]),
            station("Toppings", [
                item("Pearls (boba)", tags: ["Vegan", "Vegetarian"]),
                item("Grass jelly", tags: ["Vegan", "Vegetarian"]),
                item("Pudding", tags: ["Vegetarian"]),
            ]),
        ]

        private static let tortillaFrescaStations: [MenuStation] = [
            station("Grill", [
                item("Chicken burrito"),
                item("Carne asada burrito"),
                item("Bean & cheese burrito", tags: ["Vegetarian"]),
                item("Carne asada tacos"),
                item("Chicken tacos"),
                item("Cheese quesadilla", tags: ["Vegetarian"]),
                item("Super nachos"),
            ]),
            station("Sides", [
                item("Cilantro lime rice", tags: ["Vegan", "Vegetarian"]),
                item("Black beans", tags: ["Vegan", "Vegetarian"]),
                item("Chips & salsa", tags: ["Vegan", "Vegetarian"]),
                item("Guacamole", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let anthillPubStations: [MenuStation] = [
            station("Mains", [
                item("Anthill burger"),
                item("Impossible burger", tags: ["Vegetarian"]),
                item("Chicken sandwich"),
                item("Chicken tenders"),
                item("Buffalo wings"),
                item("Caesar salad"),
            ]),
            station("Sides & drinks", [
                item("Fries", tags: ["Vegetarian"]),
                item("Onion rings", tags: ["Vegetarian"]),
                item("Mozzarella sticks", tags: ["Vegetarian"]),
                item("Soft drinks"),
            ]),
        ]

        private static let greensToGoStations: [MenuStation] = [
            station("Salads & bowls", [
                item("Kale Caesar", tags: ["Vegetarian"]),
                item("Southwest bowl"),
                item("Greek salad", tags: ["Vegetarian"]),
                item("Harvest grain bowl", tags: ["Vegetarian"]),
                item("Chicken wrap"),
                item("Hummus veggie wrap", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Sides", [
                item("Soup of the day"),
                item("Fruit cup", tags: ["Vegan", "Vegetarian"]),
                item("Chips", tags: ["Vegan", "Vegetarian"]),
            ]),
        ]

        private static let bAndFStations: [MenuStation] = [
            station("Burgers & sandwiches", [
                item("Classic smash burger"),
                item("Double cheeseburger"),
                item("Crispy chicken sandwich"),
                item("Veggie burger", tags: ["Vegetarian"]),
            ]),
            station("Sides & shakes", [
                item("Fries"), item("Cheese fries", tags: ["Vegetarian"]),
                item("Onion rings"),
                item("Vanilla shake", tags: ["Vegetarian"]),
                item("Chocolate shake", tags: ["Vegetarian"]),
            ]),
        ]

        private static let javaCityStations: [MenuStation] = [
            station("Espresso", [
                item("Caffè latte", tags: ["Vegetarian"]),
                item("Cappuccino", tags: ["Vegetarian"]),
                item("Caffè mocha", tags: ["Vegetarian"]),
                item("Americano", tags: ["Vegan", "Vegetarian"]),
                item("Espresso", tags: ["Vegan", "Vegetarian"]),
                item("Caramel macchiato", tags: ["Vegetarian"]),
            ]),
            station("Brewed & iced", [
                item("House drip", tags: ["Vegan", "Vegetarian"]),
                item("Cold brew", tags: ["Vegan", "Vegetarian"]),
                item("Iced latte", tags: ["Vegetarian"]),
                item("Chai latte", tags: ["Vegetarian"]),
                item("Iced tea", tags: ["Vegan", "Vegetarian"]),
                item("Italian soda", tags: ["Vegetarian"]),
            ]),
            station("Bakery & bottles", [
                item("Blueberry muffin", tags: ["Vegetarian"]),
                item("Scone", tags: ["Vegetarian"]),
                item("Bagel", tags: ["Vegetarian"]),
                item("Cookie", tags: ["Vegetarian"]),
                item("Bottled water", tags: ["Vegan", "Vegetarian"]),
                item("Bottled juice"),
            ]),
        ]

        private static let greenRoomStations: [MenuStation] = [
            station("Coffee & tea", [
                item("Drip coffee", tags: ["Vegan", "Vegetarian"]),
                item("Latte", tags: ["Vegetarian"]),
                item("Americano", tags: ["Vegan", "Vegetarian"]),
                item("Chai", tags: ["Vegetarian"]),
                item("Iced tea", tags: ["Vegan", "Vegetarian"]),
            ]),
            station("Bites", [
                item("Pastry case", tags: ["Vegetarian"]),
                item("Grab-and-go snacks"),
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
        if hay.contains("green room") || hay.contains("green-room") { return .greenRoom }
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
