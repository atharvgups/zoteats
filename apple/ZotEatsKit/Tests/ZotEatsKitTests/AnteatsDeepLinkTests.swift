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

    @Test func diningStatusAndCampusOpenRowURLs() {
        let hall = AnteatsDeepLink.eat(hall: "brandywine")
        #expect(AnteatsDeepLink.parse(hall.url)?.hall == "brandywine")
        let cafe = AnteatsDeepLink.campus(placeID: "starbucks-at-student-center")
        #expect(AnteatsDeepLink.parse(cafe.url)?.placeID == "starbucks-at-student-center")
        #expect(AnteatsDeepLink.parse(AnteatsDeepLink.study().url)?.tab == .study)
        #expect(AnteatsDeepLink.parse(AnteatsDeepLink.gym().url)?.tab == .gym)
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
