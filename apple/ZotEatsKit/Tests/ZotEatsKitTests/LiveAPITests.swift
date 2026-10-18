import Foundation
import Testing
@testable import ZotEatsKit

/// Opt-in smoke tests against the real UCI endpoints.
/// Run with: ZOTEATS_LIVE_TESTS=1 swift test --filter LiveAPI
@Suite("LiveAPI", .enabled(if: ProcessInfo.processInfo.environment["ZOTEATS_LIVE_TESTS"] == "1"))
struct LiveAPITests {
    @Test func twistedRootStaysOnItsOwnHallToday() async throws {
        let service = DiningService()
        let date = UCITime.todayISO()
        let brandywine = try await service.menu(for: "brandywine", period: "Lunch", date: date)
        let anteatery = try await service.menu(for: "anteatery", period: "Lunch", date: date)
        func twistedNames(_ menu: DiningMenu) -> [String] {
            menu.stations
                .filter { DiningService.isTwistedRoot(stationName: $0.name, stationID: $0.stationID) }
                .flatMap(\.items)
                .map(\.name)
        }
        let brandywineTR = twistedNames(brandywine)
        let anteateryTR = twistedNames(anteatery)
        #expect(
            brandywine.stations
                .filter { DiningService.isTwistedRoot(stationName: $0.name, stationID: $0.stationID) }
                .allSatisfy { $0.stationID != "1929" }
        )
        #expect(
            anteatery.stations
                .filter { DiningService.isTwistedRoot(stationName: $0.name, stationID: $0.stationID) }
                .allSatisfy { $0.stationID != "1893" }
        )
        if date == "2026-09-23" {
            #expect(brandywineTR.contains { $0.localizedCaseInsensitiveContains("masala") })
            #expect(!brandywineTR.contains { $0.localizedCaseInsensitiveContains("buffalo cauliflower") })
            #expect(anteateryTR.contains { $0.localizedCaseInsensitiveContains("buffalo cauliflower") })
        }
        if date == "2026-09-25" {
            let anteateryDinner = try await service.menu(for: "anteatery", period: "Dinner", date: date)
            let brandywineDinner = try await service.menu(for: "brandywine", period: "Dinner", date: date)
            let aeDinnerTR = twistedNames(anteateryDinner)
            let bwDinnerTR = twistedNames(brandywineDinner)
            #expect(!bwDinnerTR.contains { $0.localizedCaseInsensitiveContains("buffalo tofu") })
            #expect(
                bwDinnerTR.contains { $0.localizedCaseInsensitiveContains("mac") }
                    || bwDinnerTR.contains { $0.localizedCaseInsensitiveContains("nugget") }
                    || bwDinnerTR.isEmpty
            )
            #expect(!aeDinnerTR.contains { $0.localizedCaseInsensitiveContains("buffalo cauliflower") })
        }
        if date == "2026-10-04" {
            let breakfast = try await service.menu(for: "anteatery", period: "Breakfast", date: date)
            let lunch = try await service.menu(for: "anteatery", period: "Lunch", date: date)
            let breakfastTR = twistedNames(breakfast)
            let lunchTR = twistedNames(lunch)
            #expect(!breakfastTR.contains { $0.localizedCaseInsensitiveContains("shawarma") })
            #expect(lunchTR.contains { $0.localizedCaseInsensitiveContains("shawarma") })
        }
        if date == "2026-10-03" {
            // Weekend Lunch is a thin All-Day clone. Midday TR lives on Brunch.
            #expect(!anteateryTR.isEmpty)
            #expect(!brandywineTR.isEmpty)
            #expect(anteateryTR.contains { $0.localizedCaseInsensitiveContains("hash") })
            #expect(brandywineTR.contains { $0.localizedCaseInsensitiveContains("hash") }
                || brandywineTR.contains { $0.localizedCaseInsensitiveContains("chorizo") })
            #expect(!anteateryTR.contains { $0.localizedCaseInsensitiveContains("fries") })
            #expect(anteatery.stations.first.map {
                DiningService.isTwistedRoot(stationName: $0.name, stationID: $0.stationID)
            } == true)
            #expect(brandywine.stations.first.map {
                DiningService.isTwistedRoot(stationName: $0.name, stationID: $0.stationID)
            } == true)
        }
        if date == "2026-09-27" {
            for hall in ["anteatery", "brandywine"] {
                let breakfast = try await service.menu(for: hall, period: "Breakfast", date: date)
                let lunch = try await service.menu(for: hall, period: "Lunch", date: date)
                let dinner = try await service.menu(for: hall, period: "Dinner", date: date)
                func mealNames(_ menu: DiningMenu) -> Set<String> {
                    Set(
                        menu.stations
                            .filter { !CampusMenuNormalize.isAvailableAllDay($0.name) }
                            .flatMap(\.items)
                            .map { $0.name.lowercased() }
                    )
                }
                let breakfastNames = mealNames(breakfast)
                let lunchNames = mealNames(lunch)
                let dinnerNames = mealNames(dinner)
                #expect(!breakfastNames.isEmpty)
                let breakfastOnly = breakfastNames.subtracting(lunchNames)
                #expect(!breakfastOnly.isEmpty)
                #expect(breakfastOnly.isDisjoint(with: dinnerNames))
                if hall == "brandywine" {
                    #expect(breakfastNames.contains { $0.contains("scramble") || $0.contains("tofu") })
                    #expect(!lunchNames.contains { $0.contains("scramble") })
                    #expect(!dinnerNames.contains { $0.contains("scramble") })
                }
            }
        }
    }

    @Test func diningLocationsAndMenuFromLiveAPI() async throws {
        let service = DiningService()
        let locations = await service.locations()
        #expect(locations.filter { !$0.isComingSoon }.count == 2)
        #expect(locations.contains { $0.isComingSoon && HallDirectory.isOasis($0.id) })

        if let hall = locations.first(where: { !$0.isComingSoon && !$0.availablePeriods.isEmpty }) {
            let menu = try await service.menu(for: hall.id, period: hall.availablePeriods[0])
            #expect(!menu.stations.isEmpty)
            let items = menu.stations.flatMap(\.items)
            #expect(items.contains { $0.calories != nil })
        }
    }

    /// Guards the dogfood bugs we keep fixing: no raw 404s, no allergen
    /// "not available" chips, Breakfast/Lunch/Dinner pills only, and 24h hours copy.
    @Test func eatAndCampusDogfoodInvariants() async throws {
        let dining = DiningService()
        let campus = CampusService()

        for location in await dining.locations() where !location.isComingSoon {
            let primary = DiningService.primaryPeriods(from: location.availablePeriods)
            #expect(primary.allSatisfy {
                DiningService.mealSelectorPills.contains($0)
            })
            #expect(!primary.contains(where: { $0.localizedCaseInsensitiveContains("Brunch") }))
            #expect(!primary.contains(where: { $0.localizedCaseInsensitiveContains("All Day") }))

            for period in primary {
                let menu = try await dining.menu(for: location.id, period: period)
                let allergens = menu.stations.flatMap(\.items).flatMap(\.allergens)
                #expect(!allergens.contains(where: {
                    $0.localizedCaseInsensitiveContains("not available")
                        || $0.localizedCaseInsensitiveContains("complete allergen")
                }))
            }
        }

        let unpublished = try await dining.menu(for: "anteatery", period: "Lunch", date: "2099-01-01")
        let unpublishedItems = unpublished.stations.flatMap(\.items)
        #expect(unpublishedItems.isEmpty)

        let places = try await campus.places()
        #expect(!places.contains {
            let hours = $0.todayHours ?? ""
            let compact = hours.replacingOccurrences(of: " ", with: "")
            return compact.contains("12:00AM–12:00AM") || compact.contains("12:00AM-12:00AM")
        })
        // At least one venue should surface the friendly all-day wording when applicable.
        // Soft-check: if any place claims 24h, it must use our label.
        for place in places where (place.todayHours ?? "").localizedCaseInsensitiveContains("24") {
            #expect((place.todayHours ?? "").localizedCaseInsensitiveContains("Open 24 hours"))
        }
    }

    @Test func busynessFromLiveFeed() async throws {
        let points = try await BusynessService().all()
        #expect(!points.isEmpty)
        #expect(points.contains { $0.category == "Library" })
    }

    @Test func gymStatusFromLiveData() async {
        let status = await GymService().status()
        #expect(status.todayHours != nil)
        #expect(status.weekHours.count == 7)
    }

    @Test func campusRetailFromLiveHub() async throws {
        let places = try await CampusService().places()
        #expect(places.count >= 10)
        #expect(places.contains { $0.name.contains("Starbucks") })
        #expect(!places.contains { $0.id == "the-anteatery" })
    }
}
