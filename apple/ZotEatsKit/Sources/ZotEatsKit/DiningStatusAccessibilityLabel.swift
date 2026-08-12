import Foundation

/// VoiceOver labels for Dining Status — closed halls must say closed/opens,
/// and the medium libraries tip must announce overnight closed detail plus
/// Updated freshness on open quietest tips (Quietest Library widget parity).
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

    public static func quietestTip(
        _ tip: QuietestLibraryGlance.DiningStatusTip,
        now: Date = Date()
    ) -> String {
        switch tip {
        case .open(let name, let percent, _, let updatedAt):
            let updated = UpdatedAgoCopy.relative(from: updatedAt, now: now)
            return "Quietest: \(name), \(percent) percent full, Updated \(updated)"
        case .librariesClosed(let reopenMinutes):
            let detail = StudyIdleCopy.quietestClosedDetail(reopenMinutes: reopenMinutes)
            return "\(QuietestLibraryGlance.closedTitle). \(detail)"
        }
    }
}
