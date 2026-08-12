import Foundation

/// VoiceOver labels for Dining Status — closed halls must say closed/opens,
/// and the medium libraries tip must announce overnight closed detail.
public enum DiningStatusAccessibilityLabel {
    public enum Countdown: Equatable, Sendable {
        case opens
        case closes
    }

    public static func hall(
        name: String,
        statusText: String,
        isOpen: Bool,
        occupancy: Int?,
        countdown: Countdown?
    ) -> String {
        var parts: [String] = [name, isOpen ? "open" : "closed"]
        if !statusText.isEmpty {
            parts.append(statusText)
        }
        if let occupancy {
            parts.append("\(occupancy) percent occupancy")
        }
        if let countdown {
            parts.append(countdown == .closes ? "closes" : "opens")
        }
        return parts.joined(separator: ", ")
    }

    public static func quietestTip(_ tip: QuietestLibraryGlance.DiningStatusTip) -> String {
        switch tip {
        case .open(let name, let percent, _):
            return "Quietest: \(name), \(percent) percent full"
        case .librariesClosed:
            return "\(QuietestLibraryGlance.closedTitle). \(QuietestLibraryGlance.closedDetail)"
        }
    }
}
