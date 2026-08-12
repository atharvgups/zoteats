import Testing
@testable import ZotEatsKit

@Suite("DiningLocationHoursLine")
struct DiningLocationHoursLineTests {
    @Test("Open meal shows until clock")
    func openUntil() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .open(period: "Lunch", closesAt: 14 * 60),
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "Lunch · until 2:00 PM"
        )
    }

    @Test("Before next meal names period at clock")
    func openingLater() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .openingLater(period: "Dinner", opensAt: 17 * 60),
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "Dinner at 5:00 PM"
        )
    }

    @Test("After last meal names tomorrow breakfast")
    func closedTomorrow() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .closedForToday,
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "Breakfast tomorrow · 7:15 AM"
        )
    }

    @Test("Partial board mid-day does not jump to tomorrow")
    func awaitingMoreMeals() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .awaitingMoreMeals,
                todayHours: "7:15 AM – 10:30 AM",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "More meals post later"
        )
    }

    @Test("Closed with no tomorrow stays Closed for today")
    func closedNoTomorrow() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .closedForToday,
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: nil,
                opensTomorrowPeriod: nil
            ) == "Closed for today"
        )
    }

    @Test("Unknown falls back to Hours unavailable")
    func unknown() {
        #expect(
            DiningLocationHoursLine.resolve(
                state: .unknown,
                todayHours: "Hours vary",
                opensTomorrowAtMinutes: nil,
                opensTomorrowPeriod: nil
            ) == "Hours unavailable"
        )
        #expect(
            DiningLocationHoursLine.resolve(
                state: .unknown,
                todayHours: nil,
                opensTomorrowAtMinutes: nil,
                opensTomorrowPeriod: nil
            ) == "Hours unavailable"
        )
    }

    @Test("DiningLocation.hoursLine uses openState")
    func locationConvenience() {
        let hall = DiningLocation(
            id: "anteatery",
            name: "The Anteatery",
            area: "UTC",
            openNow: false,
            todayHours: "7:15 AM – 8:00 PM",
            availablePeriods: ["Breakfast", "Lunch", "Dinner"],
            periods: [
                MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 10 * 60),
                MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60),
                MealPeriodWindow(name: "Dinner", startMinutes: 17 * 60, endMinutes: 20 * 60),
            ],
            hoursApproximate: false,
            opensTomorrowAtMinutes: 7 * 60 + 15,
            opensTomorrowPeriod: "Breakfast"
        )
        #expect(hall.hoursLine(nowMinutes: 5 * 60) == "Breakfast at 7:15 AM")
        #expect(hall.hoursLine(nowMinutes: 12 * 60) == "Lunch · until 2:00 PM")
        #expect(hall.hoursLine(nowMinutes: 21 * 60) == "Breakfast tomorrow · 7:15 AM")
    }
}
