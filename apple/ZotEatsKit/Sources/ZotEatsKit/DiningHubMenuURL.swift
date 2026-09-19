import Foundation

/// Official UCI Dining Hub location pages.
///
/// `uci.campusdish.com/LocationsAndMenus/{slug}` now dumps every hall and
/// retail spot onto the generic Locations & More index. Live menus live at
/// `uci.mydininghub.com/en/location/{url_key}`.
public enum DiningHubMenuURL: Sendable {
    public static let host = "https://uci.mydininghub.com"

    /// Hub location page for a dining-hall id or alias (`anteatery`,
    /// `the-anteatery`, `oasis`, `the-oasis-dining-hall`, …).
    public static func forHall(_ hallID: String) -> URL? {
        let raw = hallID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let key = HallDirectory.campusHubKey(for: raw) ?? raw
        return location(urlKey: key)
    }

    /// Hub location page for a Campus retail `url_key` / place id.
    public static func forPlace(placeID: String) -> URL? {
        location(urlKey: placeID)
    }

    public static func location(urlKey: String) -> URL? {
        let key = urlKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_")
        let encoded = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        return URL(string: "\(host)/en/location/\(encoded)")
    }
}
