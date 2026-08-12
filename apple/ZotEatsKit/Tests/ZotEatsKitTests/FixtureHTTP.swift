import Foundation
@testable import ZotEatsKit

/// HTTPFetching stub that serves captured API responses from the Fixtures bundle,
/// routing by URL path + query. Fails loudly on unexpected requests.
struct FixtureHTTP: HTTPFetching {
    struct UnexpectedRequest: Error {
        let url: URL
    }

    func data(from url: URL) async throws -> Data {
        let fixture: String
        let path = url.path
        if path.hasSuffix("/restaurants") {
            fixture = "restaurants"
        } else if path.hasSuffix("/restaurantToday") {
            fixture = "restaurant_today"
        } else if path.hasSuffix("/dishes/batch") {
            fixture = "dishes_batch"
        } else if path.hasSuffix("/dateRange") {
            fixture = "date_range"
        } else if url.host == "waitz.io" {
            fixture = "waitz"
        } else if url.host?.contains("libcal") == true {
            fixture = "libcal_hours_today"
        } else if url.host?.contains("elevate-dxp.com") == true {
            let query = url.query ?? ""
            fixture = query.contains("getLocationMealPeriodRecipes") ? "campus_menu" : "campus_locations"
        } else {
            throw UnexpectedRequest(url: url)
        }
        return try Self.load(fixture)
    }

    static func load(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json")
            ?? Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

/// HTTPFetching stub that always fails, for testing degraded paths.
struct FailingHTTP: HTTPFetching {
    func data(from url: URL) async throws -> Data {
        throw HTTPError.network(underlying: URLError(.notConnectedToInternet), url: url)
    }
}

/// Stub that answers every request with HTTP 404 (unpublished menu day).
struct NotFoundHTTP: HTTPFetching {
    func data(from url: URL) async throws -> Data {
        throw HTTPError.badStatus(code: 404, url: url)
    }
}

/// Mutable dining HTTP — first `restaurantToday` responses are empty boards;
/// after `publish()`, subsequent reads return the full fixture. Used to prove
/// `forceRefresh` bypasses the 20-minute today TTL when Lunch/Dinner lands.
actor PublishProbeHTTP: HTTPFetching {
    private var published = false
    private(set) var restaurantTodayHits = 0

    func publish() {
        published = true
    }

    func todayHits() -> Int { restaurantTodayHits }

    func data(from url: URL) async throws -> Data {
        let path = url.path
        if path.hasSuffix("/restaurants") {
            return try FixtureHTTP.load("restaurants")
        }
        if path.hasSuffix("/restaurantToday") {
            restaurantTodayHits += 1
            if published {
                return try FixtureHTTP.load("restaurant_today")
            }
            let hall = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "id" })?
                .value ?? "anteatery"
            return Data(
                #"{"ok":true,"data":{"id":"\#(hall)","periods":{}}}"#.utf8
            )
        }
        if path.hasSuffix("/dishes/batch") {
            return try FixtureHTTP.load("dishes_batch")
        }
        if path.hasSuffix("/dateRange") {
            return try FixtureHTTP.load("date_range")
        }
        throw FixtureHTTP.UnexpectedRequest(url: url)
    }
}

/// Serves today's fixture board always; tomorrow (and later) stay empty until
/// `publish(dateISO:)` so forceRefresh can prove next-open metadata updates.
actor TomorrowPublishHTTP: HTTPFetching {
    private let todayISO: String
    private var publishedDates: Set<String> = []
    private(set) var hitsByDate: [String: Int] = [:]

    init(todayISO: String) {
        self.todayISO = todayISO
    }

    func publish(dateISO: String) {
        publishedDates.insert(dateISO)
    }

    func hits(for dateISO: String) -> Int {
        hitsByDate[dateISO] ?? 0
    }

    func data(from url: URL) async throws -> Data {
        let path = url.path
        if path.hasSuffix("/restaurants") {
            return try FixtureHTTP.load("restaurants")
        }
        if path.hasSuffix("/restaurantToday") {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let hall = items?.first(where: { $0.name == "id" })?.value ?? "anteatery"
            let date = items?.first(where: { $0.name == "date" })?.value ?? todayISO
            hitsByDate[date, default: 0] += 1
            if date == todayISO || publishedDates.contains(date) {
                return try FixtureHTTP.load("restaurant_today")
            }
            return Data(
                #"{"ok":true,"data":{"id":"\#(hall)","periods":{}}}"#.utf8
            )
        }
        if path.hasSuffix("/dishes/batch") {
            return try FixtureHTTP.load("dishes_batch")
        }
        if path.hasSuffix("/dateRange") {
            return try FixtureHTTP.load("date_range")
        }
        throw FixtureHTTP.UnexpectedRequest(url: url)
    }
}
