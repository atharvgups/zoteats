import Testing
@testable import ZotEatsKit

@Suite("CampusPlaceHoursLine")
struct CampusPlaceHoursLineTests {
    @Test("Before open prefers Opens at over today's full window")
    func beforeOpen() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: false,
                todayHours: "7:30 AM – 4:00 PM",
                opensAtMinutes: 7 * 60 + 30,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: 7 * 60 + 30
            ) == "Opens at 7:30 AM"
        )
    }

    @Test("After close names tomorrow's open")
    func afterClose() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: false,
                todayHours: "7:30 AM – 4:00 PM",
                opensAtMinutes: nil,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: 8 * 60
            ) == "Opens tomorrow at 8:00 AM"
        )
    }

    @Test("After close with no tomorrow open never echoes past window")
    func afterCloseNoTomorrow() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: false,
                todayHours: "7:30 AM – 4:00 PM",
                opensAtMinutes: nil,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: nil
            ) == "Closed today"
        )
    }

    @Test("Open uses closesAtMinutes")
    func openUntil() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: true,
                todayHours: "7:30 AM – 4:00 PM",
                opensAtMinutes: nil,
                closesAtMinutes: 16 * 60,
                opensTomorrowAtMinutes: nil
            ) == "Open until 4:00 PM"
        )
    }

    @Test("Open without close falls back to todayHours close segment")
    func openFallback() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: true,
                todayHours: "10:00 AM – 8:00 PM",
                opensAtMinutes: 12 * 60,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: nil
            ) == "Open until 8:00 PM"
        )
    }

    @Test("Known closed with no hours stays Closed today")
    func knownClosed() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: false,
                todayHours: nil,
                opensAtMinutes: nil,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: nil,
                hoursKnown: true
            ) == "Closed today"
        )
    }

    @Test("Unknown schedule says Hours unavailable")
    func unknownClosed() {
        #expect(
            CampusPlaceHoursLine.resolve(
                openNow: false,
                todayHours: nil,
                opensAtMinutes: nil,
                closesAtMinutes: nil,
                opensTomorrowAtMinutes: nil,
                hoursKnown: false
            ) == "Hours unavailable"
        )
    }

    @Test("CampusPlace.hoursLine mirrors resolve")
    func placeConvenience() {
        let place = CampusPlace(
            id: "starbucks",
            name: "Starbucks @ Student Center",
            category: "Coffee & Cafés",
            openNow: false,
            todayHours: "7:30 AM – 4:00 PM",
            opensAtMinutes: 7 * 60 + 30,
            opensTomorrowAtMinutes: 7 * 60 + 30
        )
        #expect(place.hoursLine == "Opens at 7:30 AM")
    }

    @Test("Widget open hours prefer closesAt")
    func widgetOpen() {
        #expect(
            CampusPlaceHoursLine.widgetOpenHours(
                todayHours: "7:30 AM – 4:00 PM",
                closesAtMinutes: 16 * 60
            ) == "until 4:00 PM"
        )
    }
}
