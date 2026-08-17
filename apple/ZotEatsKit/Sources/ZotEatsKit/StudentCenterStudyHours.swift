import Foundation

/// Published Student Center study-space hours (studentcenter.uci.edu).
/// Live Occuspace % is **not** shown — Amy Schulz (Aug 2026): still
/// recalibrating; they will publish study-space data on the website.
public enum StudentCenterStudyHours {
    public static let occupancyNote =
        "Live occupancy is being recalibrated. Student Center will share it on their site — we’ll show it then."

    public static let sourceURL = URL(string: "https://studentcenter.uci.edu/learn-and-enjoy/study/")!

    public struct Space: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let location: String
        public let hours: String
        public let isOpen: Bool

        public init(id: String, name: String, location: String, hours: String, isOpen: Bool) {
            self.id = id
            self.name = name
            self.location = location
            self.hours = hours
            self.isOpen = isOpen
        }
    }

    /// Courtyard / Commuter / Hillside — the three spaces with published clocks.
    public static func spaces(now: Date = Date()) -> [Space] {
        let minutes = UCITime.nowMinutes(now: now)
        let weekday = UCITime.weekdayName(now: now)
        let isWeekend = weekday == "Saturday" || weekday == "Sunday"
        return [
            Space(
                id: "sc-courtyard",
                name: "Courtyard Study Lounge",
                location: "Level 1 · B109",
                hours: "7:00 AM – midnight",
                isOpen: minutes >= 7 * 60 && minutes < 24 * 60
            ),
            Space(
                id: "sc-commuter",
                name: "Commuter Lounge",
                location: "Level 1 · A138",
                hours: isWeekend ? "8:00 AM – 5:00 PM" : "7:30 AM – 8:00 PM",
                isOpen: isWeekend
                    ? minutes >= 8 * 60 && minutes < 17 * 60
                    : minutes >= 7 * 60 + 30 && minutes < 20 * 60
            ),
            Space(
                id: "sc-hillside",
                name: "Hillside Lounge",
                location: "Level 2 · B203",
                hours: isWeekend ? "Closed weekends" : "7:30 AM – 5:00 PM",
                isOpen: !isWeekend && minutes >= 7 * 60 + 30 && minutes < 17 * 60
            ),
        ]
    }
}
