import Foundation

/// POSTs a `repository_dispatch` event to this repo. The write token is a
/// fine-grained PAT limited to atharvgups/zoteats; GitHub requires Contents:
/// write for this API. The app never calls the Contents API itself.
public enum GitHubIngest {
    public static let dispatchURL = URL(
        string: "https://api.github.com/repos/atharvgups/zoteats/dispatches"
    )!

    public static func dispatch<Payload: Encodable>(
        http: any HTTPFetching,
        eventType: String,
        payload: Payload,
        writeToken: String
    ) async -> Bool {
        let token = writeToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !eventType.isEmpty else { return false }
        let envelope = Envelope(event_type: eventType, client_payload: payload)
        guard let body = try? JSONEncoder().encode(envelope) else { return false }
        do {
            _ = try await http.send(
                method: "POST",
                url: dispatchURL,
                headers: [
                    "Accept": "application/vnd.github+json",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(token)",
                    "X-GitHub-Api-Version": "2022-11-28",
                ],
                body: body
            )
            return true
        } catch {
            return false
        }
    }

    private struct Envelope<Payload: Encodable>: Encodable {
        var event_type: String
        var client_payload: Payload
    }
}
