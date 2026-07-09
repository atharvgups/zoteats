import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum HTTPError: Error, LocalizedError {
    case badStatus(code: Int, url: URL)
    case network(underlying: Error, url: URL)
    case decoding(underlying: Error, url: URL)

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code, let url):
            "Request to \(url.host ?? "server") failed (HTTP \(code))."
        case .network(_, let url):
            "Couldn't reach \(url.host ?? "server"). Check your connection."
        case .decoding(_, let url):
            "Unexpected response from \(url.host ?? "server")."
        }
    }
}

/// Abstraction over URLSession so services can be tested with fixture data.
public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

/// Thin fetch helper with a timeout — port of main/services/http.ts.
public struct HTTPClient: HTTPFetching {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 12) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "ZotEats/1.0 (UCI student utility)",
        ]
        self.session = URLSession(configuration: config)
        self.timeout = timeout
    }

    public func data(from url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            #if canImport(FoundationNetworking)
            // swift-corelibs-foundation on Linux lacks the async URLSession API.
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: url) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.unknown))
                    }
                }.resume()
            }
            #else
            (data, response) = try await session.data(from: url)
            #endif
        } catch {
            throw HTTPError.network(underlying: error, url: url)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPError.badStatus(code: http.statusCode, url: url)
        }
        return data
    }
}

extension HTTPFetching {
    func json<T: Decodable>(_ type: T.Type, from url: URL, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let data = try await data(from: url)
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw HTTPError.decoding(underlying: error, url: url)
        }
    }
}
