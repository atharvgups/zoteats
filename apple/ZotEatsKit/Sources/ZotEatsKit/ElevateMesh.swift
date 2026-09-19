import Foundation

/// Shared client for UCI's dining hub GraphQL mesh (elevate-dxp.com).
/// Campus retail and residential commons both live here; headers are static
/// public values from the site's own JS bundle (same path as icssc/anteater-api).
enum ElevateMesh {
    static let url = "https://api.elevate-dxp.com/api/mesh/c087f756-cc72-4649-a36f-3a41b700c519/graphql"

    static let headers: [String: String] = [
        "Referer": "https://uci.mydininghub.com/",
        "Origin": "https://uci.mydininghub.com",
        "store": "ch_uci_en",
        "x-api-key": "ElevateAPIProd",
        "magento-store-code": "ch_uci",
        "magento-website-code": "ch_uci",
        "magento-store-view-code": "ch_uci_en",
    ]

    struct Envelope<T: Decodable & Sendable>: Decodable, Sendable {
        let data: T?
    }

    static func get<T: Decodable & Sendable>(
        _ type: T.Type,
        query: String,
        variables: String,
        http: any HTTPFetching
    ) async throws -> T {
        var components = URLComponents(string: url)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "variables", value: variables),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let data = try await http.data(from: url, headers: headers)
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard let payload = envelope.data else {
            throw HTTPError.decoding(underlying: URLError(.cannotParseResponse), url: url)
        }
        return payload
    }
}

/// A few polite retries for flaky third-party GETs. Does not retry 404s.
enum FetchRetry {
    static func run<T: Sendable>(
        attempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error = URLError(.unknown)
        for attempt in 0..<attempts {
            do {
                return try await operation()
            } catch let error as HTTPError {
                lastError = error
                if case .badStatus(let code, _) = error, (400..<500).contains(code) {
                    throw error
                }
            } catch {
                lastError = error
            }
            if attempt < attempts - 1 {
                let nanos = UInt64(400_000_000) << attempt
                try await Task.sleep(nanoseconds: nanos)
            }
        }
        throw lastError
    }
}
