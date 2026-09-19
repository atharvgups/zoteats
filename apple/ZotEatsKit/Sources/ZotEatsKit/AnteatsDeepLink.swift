import Foundation

/// Shared `anteats://` destinations for widgets, notification taps, and
/// `onOpenURL`. Keeps tab routing + Eat/Campus/Study query params in one place.
public struct AnteatsDeepLink: Equatable, Sendable {
    public enum Tab: String, Equatable, Sendable {
        case eat
        case campus
        case gym
        case study
    }

    public var tab: Tab
    /// Anteater API hall id (`anteatery`, …).
    public var hall: String?
    public var period: String?
    public var dish: String?
    /// Future ISO date for Eat browse; nil/today means live today.
    public var date: String?
    /// Campus hub url key without `campus:` prefix.
    public var placeID: String?
    /// Waitz facility id for Study (Quietest Library / Dining tip).
    public var facilityID: Int?

    public init(
        tab: Tab,
        hall: String? = nil,
        period: String? = nil,
        dish: String? = nil,
        date: String? = nil,
        placeID: String? = nil,
        facilityID: Int? = nil
    ) {
        self.tab = tab
        self.hall = hall
        self.period = period
        self.dish = dish
        self.date = date
        self.placeID = placeID
        self.facilityID = facilityID
    }

    public static func parse(_ url: URL) -> AnteatsDeepLink? {
        guard let scheme = url.scheme?.lowercased(), scheme == "anteats" else { return nil }
        let host = (url.host ?? url.pathComponents.drop(while: { $0 == "/" }).first)?
            .lowercased()
        guard let host, let tab = Tab(rawValue: normalizedHost(host)) else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }

        let facility: Int? = value("facility").flatMap(Int.init)

        return AnteatsDeepLink(
            tab: tab,
            hall: value("hall"),
            period: value("period"),
            dish: value("dish"),
            date: value("date"),
            placeID: value("place"),
            facilityID: facility
        )
    }

    /// Prefer `deeplink` URL string; fall back to structured alert keys.
    public static func fromNotification(userInfo: [AnyHashable: Any]) -> AnteatsDeepLink? {
        if let raw = userInfo["deeplink"] as? String,
           let url = URL(string: raw),
           let link = parse(url) {
            return link
        }
        let period = (userInfo["period"] as? String)?.nilIfEmpty
        let dish = (userInfo["dish"] as? String)?.nilIfEmpty
        let date = (userInfo["date"] as? String)?.nilIfEmpty
        if let place = userInfo["place"] as? String {
            if place.hasPrefix("dining:") {
                let hall = String(place.dropFirst("dining:".count))
                // Opening Alerts stash period/date beside `place`; don't drop
                // them when the deeplink URL path isn't used.
                return AnteatsDeepLink(
                    tab: .eat,
                    hall: hall.nilIfEmpty,
                    period: period,
                    dish: dish,
                    date: date
                )
            }
            if place.hasPrefix("campus:") {
                let id = String(place.dropFirst("campus:".count))
                return AnteatsDeepLink(tab: .campus, placeID: id.nilIfEmpty)
            }
        }
        if let hallID = (userInfo["hallID"] as? String)?.nilIfEmpty {
            return AnteatsDeepLink(
                tab: .eat,
                hall: hallID,
                period: period,
                dish: dish,
                date: date
            )
        }
        if let date {
            return AnteatsDeepLink(tab: .eat, date: date)
        }
        return nil
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "anteats"
        components.host = tab.rawValue
        var items: [URLQueryItem] = []
        if let hall { items.append(URLQueryItem(name: "hall", value: hall)) }
        if let period { items.append(URLQueryItem(name: "period", value: period)) }
        if let dish { items.append(URLQueryItem(name: "dish", value: dish)) }
        if let date { items.append(URLQueryItem(name: "date", value: date)) }
        if let placeID { items.append(URLQueryItem(name: "place", value: placeID)) }
        if let facilityID { items.append(URLQueryItem(name: "facility", value: String(facilityID))) }
        if !items.isEmpty { components.queryItems = items }
        return components.url ?? URL(string: "anteats://\(tab.rawValue)")!
    }

    public static func eat(
        hall: String? = nil,
        period: String? = nil,
        dish: String? = nil,
        date: String? = nil
    ) -> AnteatsDeepLink {
        AnteatsDeepLink(tab: .eat, hall: hall, period: period, dish: dish, date: date)
    }

    public static func campus(placeID: String?) -> AnteatsDeepLink {
        AnteatsDeepLink(tab: .campus, placeID: placeID)
    }

    public static func study(facilityID: Int? = nil) -> AnteatsDeepLink {
        AnteatsDeepLink(tab: .study, facilityID: facilityID)
    }

    public static func gym() -> AnteatsDeepLink {
        AnteatsDeepLink(tab: .gym)
    }

    private static func normalizedHost(_ host: String) -> String {
        switch host {
        case "dining": return Tab.eat.rawValue
        case "busyness": return Tab.study.rawValue
        default: return host
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
