import Foundation
import Testing
@testable import ZotEatsKit

@Suite("OasisBoard")
struct OasisBoardTests {
    private func item(_ id: String, _ name: String, stationID: String? = nil) -> MenuItem {
        MenuItem(
            id: id,
            name: name,
            description: nil,
            calories: 100,
            servingSize: nil,
            allergens: [],
            dietaryTags: [],
            stationID: stationID
        )
    }

    @Test func groupsHubSkusUnderRealStationNames() {
        let products = [
            "chicken": item("chicken", "Mesquite Chicken", stationID: "306552"),
            "mac": item("mac", "Mac & Cheese", stationID: "306552"),
            "peas": item("peas", "Steamed Green Peas", stationID: "306552"),
            "pizza": item("pizza", "Pepperoni Pizza", stationID: "306564"),
            "sandwich": item("sandwich", "Grilled Chicken Sandwich", stationID: "306558"),
            "lettuce": item("lettuce", "Green Leaf Lettuce", stationID: "306558"),
            "soup": item("soup", "Tomato Basil Soup", stationID: "306555"),
            "cookie": item("cookie", "Sugar Cookie", stationID: "306561"),
            "ravioli": item("ravioli", "Baked Cheese Ravioli", stationID: "306567"),
        ]
        let board = OasisBoard.postedBoard(
            mealPeriodSKUs: [
                (name: "Lunch", skus: Array(products.keys)),
                (name: "Dinner", skus: ["chicken", "pizza", "sandwich"]),
                (name: "All Day", skus: Array(products.keys)),
                (name: "Brunch", skus: Array(products.keys)),
            ],
            stationSKUs: [
                (id: "306552", skus: ["chicken", "mac", "peas"]),
                (id: "306555", skus: ["soup"]),
                (id: "306558", skus: ["sandwich", "lettuce", "lettuce"]),
                (id: "306561", skus: ["cookie"]),
                (id: "306564", skus: ["pizza"]),
                (id: "306567", skus: ["ravioli"]),
            ],
            directory: OasisBoard.directory(overlaying: []),
            products: products
        )
        #expect(board.availablePeriods == ["Lunch", "Dinner"])
        #expect(board.stationsByPeriod["Brunch"] == nil)
        #expect(board.stationsByPeriod["All Day"] == nil)

        let lunch = board.stations(for: "Lunch")
        #expect(lunch.map(\.name) == [
            "Main", "Salad & Soup", "Grill/Deli", "Desserts", "Pizza", "Saute",
        ])
        #expect(lunch.map(\.stationID) == [
            "306552", "306555", "306558", "306561", "306564", "306567",
        ])
        #expect(lunch.first { $0.name == "Main" }?.items.map(\.name) == [
            "Mesquite Chicken", "Mac & Cheese", "Steamed Green Peas",
        ])
        #expect(lunch.first { $0.name == "Grill/Deli" }?.items.map(\.name) == [
            "Grilled Chicken Sandwich", "Green Leaf Lettuce",
        ])
        #expect(lunch.allSatisfy { $0.name != "Lunch" && $0.name != "Menu" })

        #expect(lunch.first { $0.name == "Pizza" }?.serviceLabel == OasisBoard.kioskOrderOnlyLabel)
        #expect(lunch.first { $0.name == "Grill/Deli" }?.serviceLabel == OasisBoard.kioskOrderOnlyLabel)
        #expect(lunch.first { $0.name == "Main" }?.serviceLabel == OasisBoard.grabAndGoLabel)
        #expect(lunch.first { $0.name == "Salad & Soup" }?.serviceLabel == OasisBoard.grabAndGoLabel)
        #expect(lunch.first { $0.name == "Desserts" }?.serviceLabel == OasisBoard.grabAndGoLabel)
        #expect(lunch.first { $0.name == "Saute" }?.serviceLabel == OasisBoard.grabAndGoLabel)

        let dinner = board.stations(for: "Dinner")
        #expect(dinner.map(\.name) == ["Main", "Grill/Deli", "Pizza"])
        #expect(dinner.first { $0.name == "Main" }?.items.map(\.name) == ["Mesquite Chicken"])
    }

    @Test func dropsPeasOnlyHotLineWithoutInventingAnEntree() {
        let products = [
            "peas": item("peas", "Steamed Green Peas", stationID: "306552"),
            "pizza": item("pizza", "Classic Cheese Pizza", stationID: "306564"),
        ]
        let stations = OasisBoard.stationsForPeriod(
            periodSKUs: ["peas", "pizza"],
            stationSKUs: [
                (id: "306552", skus: ["peas"]),
                (id: "306564", skus: ["pizza"]),
            ],
            directory: OasisBoard.directory(overlaying: []),
            products: products
        )
        #expect(stations.map(\.name) == ["Pizza"])
        #expect(!stations.contains { $0.items.contains { $0.name == "Steamed Green Peas" } })
        #expect(!stations.contains { $0.name == "Main" })
    }

    @Test func keepsSaladAndSoupEvenWhenMostDishesAreSides() {
        let products = [
            "salad": item("salad", "Italian Lentil Salad", stationID: "306555"),
            "soup": item("soup", "Tomato Basil Soup", stationID: "306555"),
        ]
        let stations = OasisBoard.stationsForPeriod(
            periodSKUs: ["salad", "soup"],
            stationSKUs: [(id: "306555", skus: ["salad", "soup"])],
            directory: OasisBoard.directory(overlaying: []),
            products: products
        )
        #expect(stations.map(\.name) == ["Salad & Soup"])
        #expect(stations[0].items.map(\.name) == ["Italian Lentil Salad", "Tomato Basil Soup"])
        #expect(stations[0].serviceLabel == OasisBoard.grabAndGoLabel)
    }

    @Test func kioskLabelFollowsHubServeUpCopyNotGuesses() {
        #expect(OasisBoard.serviceLabel(stationName: "Pizza") == "Kiosk order only")
        #expect(OasisBoard.serviceLabel(stationName: "Grill/Deli") == "Kiosk order only")
        #expect(OasisBoard.serviceLabel(stationName: "Main") == "Grab and go")
        #expect(OasisBoard.serviceLabel(stationName: "Saute") == "Grab and go")
        #expect(OasisBoard.serviceLabel(stationName: "Salad & Soup") == "Grab and go")
        #expect(OasisBoard.serviceLabel(stationName: "Desserts") == "Grab and go")
        #expect(OasisBoard.serviceLabel(stationName: "") == nil)
        #expect(MenuStation(name: "Deli", items: [item("t", "Turkey")], stationID: "1950").serviceLabel == nil)
        #expect(!OasisBoard.kioskOrderOnlyLabel.contains("\u{2014}"))
        #expect(!OasisBoard.grabAndGoLabel.contains("\u{2014}"))
        #expect(!OasisBoard.kioskOrderOnlyLabel.contains("\u{2013}"))
    }

    @Test func liveHubMenuGroupsStationsAndKeepsAnteateryRankerAlone() async throws {
        let mondayNoon = ISO8601DateFormatter().date(from: "2026-11-04T19:30:00Z")!
        let service = DiningService(http: OasisLiveHubHTTP(), now: { mondayNoon })
        let lunch = try await service.menu(for: "oasis", period: "Lunch", date: "2026-11-04")
        #expect(lunch.stations.map(\.name) == ["Main", "Pizza"])
        #expect(lunch.stations.contains { $0.items.contains { $0.name == "Rice Bowl" } })
        #expect(lunch.stations.contains { $0.items.contains { $0.name == "Pepperoni Pizza" } })
        #expect(!lunch.stations.contains { $0.name == "Lunch" })
        #expect(lunch.stations.first { $0.name == "Pizza" }?.serviceLabel == "Kiosk order only")
        #expect(lunch.stations.first { $0.name == "Main" }?.serviceLabel == "Grab and go")

        let dinner = try await service.menu(for: "oasis", period: "Dinner", date: "2026-11-04")
        #expect(dinner.stations.map(\.name) == ["Main"])
        #expect(dinner.stations[0].items.map(\.name) == ["Rice Bowl"])

        let fridayDinner = try await service.menu(for: "oasis", period: "Dinner", date: "2026-11-06")
        #expect(fridayDinner.stations.isEmpty)

        let veterans = try await service.menu(for: "oasis", period: "Lunch", date: "2026-11-11")
        #expect(veterans.stations.isEmpty)

        let anteateryLunch = [
            MenuStation(name: "Sizzle Grill", items: [item("b", "Burger")], stationID: "1935"),
            MenuStation(name: "The Twisted Root", items: [item("t", "Tofu")], stationID: "1929"),
            MenuStation(name: "Oven", items: [item("p", "Cheese Pizza")], stationID: "1941"),
        ]
        #expect(
            DiningService.orderedStations(anteateryLunch, hallID: "anteatery").map(\.name)
                == ["The Twisted Root", "Oven", "Sizzle Grill"]
        )
        #expect(
            DiningService.orderedStations(lunch.stations, hallID: "oasis").map(\.name)
                == ["Main", "Pizza"]
        )

        let hubOrder = [
            MenuStation(name: "Main", items: [item("c", "Chicken")], stationID: "306552"),
            MenuStation(name: "Salad & Soup", items: [item("s", "Soup")], stationID: "306555"),
            MenuStation(name: "Grill/Deli", items: [item("g", "Sandwich")], stationID: "306558"),
            MenuStation(name: "Desserts", items: [item("d", "Cookie")], stationID: "306561"),
            MenuStation(name: "Pizza", items: [item("p", "Pepperoni Pizza")], stationID: "306564"),
            MenuStation(name: "Saute", items: [item("r", "Ravioli")], stationID: "306567"),
        ]
        #expect(DiningService.orderedStations(hubOrder, hallID: "oasis").map(\.name) == hubOrder.map(\.name))
        #expect(
            DiningService.pinTwistedRootFirst(hubOrder).map(\.name)
                != hubOrder.map(\.name)
        )
    }
}
