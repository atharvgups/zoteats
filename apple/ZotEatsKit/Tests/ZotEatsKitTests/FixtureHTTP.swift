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
        } else if url.host == "waitz.io" {
            fixture = "waitz"
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
