import Foundation
import Testing
@testable import ZotEatsKit

/// The captured fixtures' active schedule window covers July 2026.
/// Monday 2026-07-13, 10:00 AM Pacific (17:00 UTC).
private let mondayMorning = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")!
/// Sunday 2026-07-12, 10:00 AM Pacific.
private let sundayMorning = ISO8601DateFormatter().date(from: "2026-07-12T17:00:00Z")!

@Suite("CampusService (fixtures)")
struct CampusServiceTests {
    @Test func listsRetailPlacesExcludingCommons() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let places = try await service.places()
        #expect(!places.isEmpty)
        #expect(!places.contains { $0.id == "the-anteatery" || $0.id == "brandywine" })
        #expect(places.contains { $0.name.contains("Starbucks") })
        #expect(places.contains { $0.name.contains("Panda Express") })
    }

    @Test func categorization() {
        #expect(CampusService.categorize("Starbucks @ Student Center") == "Coffee & Cafés")
        #expect(CampusService.categorize("Zot N Go Express @ Side Door") == "Markets")
        #expect(CampusService.categorize("Panda Express @ West Food Court") == "Food Courts")
        #expect(CampusService.categorize("Anthill Pub") == "Restaurants & Pubs")
        #expect(CampusService.categorize("Jamba @ East Food Court") == "Coffee & Cafés")
    }

    @Test func weekdayHoursResolveFromActiveSchedule() async throws {
        // The July special schedule has Starbucks open Mo-Fr 07:30-16:00, weekends off.
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let starbucks = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(starbucks != nil)
        #expect(starbucks?.openNow == true) // Monday 10 AM within 07:30-16:00
        #expect(starbucks?.todayHours?.contains("7:30 AM") == true)
        // Open venues expose close minutes so Campus Open widgets can reload at the boundary.
        #expect(starbucks?.closesAtMinutes == 16 * 60)
        // Single continuous window — no later reopen today.
        #expect(starbucks?.opensAtMinutes == nil)
    }

    @Test func nextOpeningMinutesFindsLaterWindowWhileOpen() {
        let windows = [
            CampusService.TimeWindow(start: 7 * 60 + 30, end: 11 * 60),
            CampusService.TimeWindow(start: 16 * 60 + 30, end: 21 * 60),
        ]
        // 10 AM inside the morning window — still schedule the evening reopen.
        #expect(CampusService.nextOpeningMinutes(windows: windows, nowMinutes: 10 * 60) == 16 * 60 + 30)
        // Before either window — morning open.
        #expect(CampusService.nextOpeningMinutes(windows: windows, nowMinutes: 6 * 60) == 7 * 60 + 30)
        // After the last window.
        #expect(CampusService.nextOpeningMinutes(windows: windows, nowMinutes: 22 * 60) == nil)
    }

    @Test func followingOpeningsReturnsEveryRemainingWindow() {
        let windows = [
            CampusService.TimeWindow(start: 16 * 60 + 30, end: 21 * 60),
            CampusService.TimeWindow(start: 7 * 60 + 30, end: 11 * 60),
            CampusService.TimeWindow(start: 0, end: 0), // all-day — skipped
        ]
        let morning = CampusService.followingOpenings(windows: windows, nowMinutes: 6 * 60)
        #expect(morning.map(\.start) == [7 * 60 + 30, 16 * 60 + 30])
        let duringMorning = CampusService.followingOpenings(windows: windows, nowMinutes: 10 * 60)
        #expect(duringMorning.map(\.start) == [16 * 60 + 30])
        #expect(CampusService.followingOpenings(windows: windows, nowMinutes: 22 * 60).isEmpty)
        #expect(CampusService.allOpenings(windows: windows).map(\.start) == [7 * 60 + 30, 16 * 60 + 30])
    }

    @Test func weekendOffMeansClosedWithNoHours() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { sundayMorning })
        let starbucks = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(starbucks?.openNow == false)
        #expect(starbucks?.todayHours == nil)
        #expect(starbucks?.closesAtMinutes == nil)
        #expect(starbucks?.hoursKnown == true)
        // Sunday evening watchers still need Monday's open for opening alerts.
        #expect(starbucks?.opensTomorrowAtMinutes == 7 * 60 + 30)
        #expect(starbucks?.hoursLine == "Opens tomorrow at 7:30 AM")
    }

    @Test func fridayAfterCloseNamesMondayOpen() async throws {
        // Friday 2026-07-10, 4:30 PM Pacific — Starbucks closed; Saturday/Sunday off.
        let fridayAfternoon = ISO8601DateFormatter().date(from: "2026-07-10T23:30:00Z")!
        let service = CampusService(http: FixtureHTTP(), now: { fridayAfternoon })
        let starbucks = try await service.places().first { $0.id == "starbucks-at-student-center" }
        #expect(starbucks?.openNow == false)
        #expect(starbucks?.todayHours?.contains("7:30 AM") == true)
        #expect(starbucks?.opensAtMinutes == nil)
        #expect(starbucks?.opensTomorrowAtMinutes == nil) // Sat off
        #expect(starbucks?.opensNextWeekday == "Monday")
        #expect(starbucks?.opensNextDayOffset == 3)
        #expect(starbucks?.opensNextAtMinutes == 7 * 60 + 30)
        #expect(starbucks?.hoursKnown == true)
        #expect(starbucks?.hoursLine == "Opens Monday at 7:30 AM")
        #expect(!starbucks!.nextOpenWindows.isEmpty)
    }

    @Test func openingHoursRuleParsing() {
        // First matching rule wins; later contradictory rules are ignored.
        let hours = "Mo-Fr 07:30-16:00; Sa off; Sa 07:30-16:00; Su off; Su 07:30-16:00"
        #expect(CampusService.window(from: hours, weekday: "Wednesday") == .init(start: 450, end: 960))
        #expect(CampusService.window(from: hours, weekday: "Saturday") == nil)
        #expect(CampusService.window(from: hours, weekday: "Sunday") == nil)
        #expect(CampusService.window(from: "Mo-Su off", weekday: "Monday") == nil)
        #expect(CampusService.window(from: "Mo,We,Fr 09:00-14:00", weekday: "Friday") == .init(start: 540, end: 840))
        #expect(CampusService.window(from: "Mo,We,Fr 09:00-14:00", weekday: "Tuesday") == nil)
    }

    @Test func midnightToMidnightMeansOpenAllDay() {
        let allDay = CampusService.TimeWindow(start: 0, end: 0)
        #expect(allDay.isAllDay)
        #expect(allDay.contains(minute: 0))
        #expect(allDay.contains(minute: 12 * 60))
        #expect(allDay.contains(minute: 23 * 60 + 59))
        #expect(CampusService.format(windows: [allDay]) == "Open 24 hours")
    }

    @Test func allergenStatementIgnoresUnavailableBoilerplate() {
        #expect(
            CampusService.allergens(
                fromStatement: "Complete allergen information is not available. Please contact the on-site manager for assistance."
            ).isEmpty
        )
        #expect(CampusService.allergens(fromStatement: "Contains:") == [])
        #expect(CampusService.allergens(fromStatement: "Contains: Eggs, Milk") == ["Eggs", "Milk"])
        #expect(CampusService.allergens(fromStatement: nil).isEmpty)
    }

    @Test func allergenIntoleranceIDsMapToLabels() {
        #expect(CampusService.allergens(fromIntoleranceIDs: ["45", "63", "39"]) == ["Milk", "Wheat", "Eggs"])
        #expect(CampusService.allergens(fromIntoleranceIDs: ["0"]).isEmpty)
        #expect(CampusService.allergens(fromIntoleranceIDs: ["45,57"]) == ["Milk", "Soy"])
    }

    @Test func publishedMenuMapsDietaryTagsAndAllergens() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let stations = try await service.menu(for: "halal-shack", date: "2026-07-13")
        #expect(!stations.isEmpty)
        let items = stations.flatMap(\.items)
        #expect(!items.isEmpty)
        #expect(items.contains { $0.calories != nil })
        // The fixture's Scrambled Eggs carries Gluten-Free(78)/Vegetarian(99)/Kosher(87)/Halal(133) + Eggs allergen.
        let eggs = items.first { $0.name == "Scrambled Eggs" }
        #expect(eggs != nil)
        #expect(eggs?.allergens.contains("Eggs") == true)
        #expect(eggs?.dietaryTags.contains("Halal") == true)
        #expect(eggs?.dietaryTags.contains("Vegetarian") == true)
        // Turmeric Tofu uses allergens_intolerances id 57 + Plant Forward recipe attr.
        let tofu = items.first { $0.name == "Turmeric Tofu Scramble" }
        #expect(tofu?.allergens.contains("Soy") == true)
        #expect(tofu?.dietaryTags.contains("Plant Forward") == true)
        #expect(tofu?.dietaryTags.contains("Vegan") == true)
    }

    @Test func networkFailurePropagates() async {
        let service = CampusService(http: FailingHTTP(), now: { mondayMorning })
        await #expect(throws: (any Error).self) {
            _ = try await service.places()
        }
    }

    @Test func menuFlagComesFromTheHub() async throws {
        let service = CampusService(http: FixtureHTTP(), now: { mondayMorning })
        let places = try await service.places()
        #expect(places.first { $0.id == "halal-shack" }?.hasMenu == true)
        #expect(places.first { $0.id == "starbucks-at-student-center" }?.hasMenu == false)
    }

    @Test func brandAndLocationSplitting() {
        let starbucks = CampusPlace(
            id: "s", name: "Starbucks @ Student Center", category: "Coffee & Cafés",
            openNow: true, todayHours: nil
        )
        #expect(starbucks.brand == "Starbucks")
        #expect(starbucks.locationDetail == "Student Center")

        let single = CampusPlace(
            id: "h", name: "Halal Shack", category: "Food Courts",
            openNow: true, todayHours: nil
        )
        #expect(single.brand == "Halal Shack")
        #expect(single.locationDetail == nil)
    }
}
