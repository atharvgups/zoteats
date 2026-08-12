import Foundation
import Testing
@testable import ZotEatsKit

@Suite("AnteatsDeepLink")
struct AnteatsDeepLinkTests {
    @Test func tabOnlyURLs() {
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://eat")!)?.tab == .eat)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://campus")!)?.tab == .campus)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://gym")!)?.tab == .gym)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://study")!)?.tab == .study)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://dining")!)?.tab == .eat)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://busyness")!)?.tab == .study)
    }

    @Test func eatQueryParams() {
        let link = AnteatsDeepLink.parse(
            URL(string: "anteats://eat?hall=anteatery&period=Lunch&dish=Crispy%20Okra&date=2026-07-16")!
        )
        #expect(link == .eat(hall: "anteatery", period: "Lunch", dish: "Crispy Okra", date: "2026-07-16"))
    }

    @Test func campusPlaceQuery() {
        let link = AnteatsDeepLink.parse(
            URL(string: "anteats://campus?place=starbucks-at-student-center")!
        )
        #expect(link == .campus(placeID: "starbucks-at-student-center"))
    }

    @Test func junkHostIsNil() {
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://settings")!) == nil)
        #expect(AnteatsDeepLink.parse(URL(string: "https://example.com")!) == nil)
    }

    @Test func roundTripsThroughURL() {
        let original = AnteatsDeepLink.eat(hall: "brandywine", period: "Dinner", dish: "Soup")
        #expect(AnteatsDeepLink.parse(original.url) == original)
    }

    @Test func todaysMenuWidgetURLIncludesHallAndPeriod() {
        let url = AnteatsDeepLink.eat(hall: "anteatery", period: "Lunch").url
        #expect(url.absoluteString.contains("hall=anteatery"))
        #expect(url.absoluteString.contains("period=Lunch"))
        let parsed = AnteatsDeepLink.parse(url)
        #expect(parsed?.tab == .eat)
        #expect(parsed?.hall == "anteatery")
        #expect(parsed?.period == "Lunch")
        #expect(parsed?.dish == nil)
    }

    @Test("Today's Menu dish tap URL keeps hall, meal, date, and dish")
    func todaysMenuDishTapRoundTrips() {
        let original = AnteatsDeepLink.eat(
            hall: "anteatery",
            period: "Lunch",
            dish: "Crispy Okra",
            date: "2026-07-16"
        )
        let parsed = AnteatsDeepLink.parse(original.url)
        #expect(parsed == original)
        #expect(parsed?.hall == "anteatery")
        #expect(parsed?.period == "Lunch")
        #expect(parsed?.dish == "Crispy Okra")
        #expect(parsed?.date == "2026-07-16")
    }

    @Test func diningStatusAndCampusOpenRowURLs() {
        let hall = AnteatsDeepLink.eat(hall: "brandywine", period: "Lunch")
        #expect(AnteatsDeepLink.parse(hall.url)?.hall == "brandywine")
        #expect(AnteatsDeepLink.parse(hall.url)?.period == "Lunch")
        let cafe = AnteatsDeepLink.campus(placeID: "starbucks-at-student-center")
        #expect(AnteatsDeepLink.parse(cafe.url)?.placeID == "starbucks-at-student-center")
        #expect(AnteatsDeepLink.parse(AnteatsDeepLink.study().url)?.tab == .study)
        #expect(AnteatsDeepLink.parse(AnteatsDeepLink.gym().url)?.tab == .gym)
    }

    @Test func studyFacilityRoundTrips() {
        let link = AnteatsDeepLink.study(facilityID: 42)
        #expect(link.url.absoluteString.contains("facility=42"))
        let parsed = AnteatsDeepLink.parse(link.url)
        #expect(parsed?.tab == .study)
        #expect(parsed?.facilityID == 42)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://study")!)?.facilityID == nil)
        #expect(AnteatsDeepLink.parse(URL(string: "anteats://busyness?facility=23")!)?.facilityID == 23)
    }

    @Test func notificationDeeplinkString() {
        let info: [AnyHashable: Any] = [
            "deeplink": "anteats://eat?hall=anteatery&period=Lunch&dish=Okra",
        ]
        let link = AnteatsDeepLink.fromNotification(userInfo: info)
        #expect(link?.hall == "anteatery")
        #expect(link?.dish == "Okra")
    }

    @Test func notificationOpeningPlaceKeys() {
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: ["place": "dining:brandywine"])
                == .eat(hall: "brandywine")
        )
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: ["place": "campus:halal-shack"])
                == .campus(placeID: "halal-shack")
        )
    }

    @Test("Opening Alert place fallback keeps meal and date")
    func notificationOpeningPlaceKeepsMealAndDate() {
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: [
                "place": "dining:anteatery",
                "period": "Lunch",
                "date": "2026-08-17",
            ]) == .eat(hall: "anteatery", period: "Lunch", date: "2026-08-17")
        )
    }

    @Test("hallID fallback keeps overnight Opening Alert date")
    func notificationHallIDKeepsDate() {
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: [
                "hallID": "brandywine",
                "period": "Breakfast",
                "date": "2026-08-18",
            ]) == .eat(hall: "brandywine", period: "Breakfast", date: "2026-08-18")
        )
    }

    @Test("deeplink string still wins over structured Opening keys")
    func notificationDeeplinkPrefersURLOverPlace() {
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: [
                "deeplink": "anteats://eat?hall=anteatery&period=Dinner",
                "place": "dining:brandywine",
                "period": "Lunch",
            ]) == .eat(hall: "anteatery", period: "Dinner")
        )
    }

    @Test func notificationFavoriteAndMenuDropKeys() {
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: [
                "hallID": "anteatery",
                "period": "Lunch",
                "dish": "Crispy Okra",
            ]) == .eat(hall: "anteatery", period: "Lunch", dish: "Crispy Okra")
        )
        #expect(
            AnteatsDeepLink.fromNotification(userInfo: ["date": "2026-07-18"])
                == .eat(date: "2026-07-18")
        )
    }
}
