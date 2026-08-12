import Foundation

/// VoiceOver for Study facility card chrome — one announcement for open/closed
/// and crowding (OccupancyBar used to double-speak percent on open rows).
public enum StudyFacilityAccessibilityLabel {
    public static func label(
        name: String,
        isOpen: Bool,
        percent: Int?,
        levelLabel: String?,
        peopleCount: Int?,
        capacity: Int?
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = [trimmed.isEmpty ? "Library" : trimmed]
        let level = levelLabel?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard StudyFacilityCrowding.showsLiveCrowding(isOpen: isOpen) else {
            parts.append("closed")
            parts.append(StudyFacilityCrowding.closedDetail)
            return parts.joined(separator: ", ")
        }

        parts.append("open")

        if let percent {
            var crowd = "\(percent) percent full"
            if let level, !level.isEmpty {
                crowd += ", \(level)"
            }
            parts.append(crowd)
        } else if let level, !level.isEmpty {
            parts.append(level)
        }

        if let peopleCount, let capacity {
            parts.append("\(peopleCount) of \(capacity) people")
        } else if let peopleCount {
            parts.append("\(peopleCount) people")
        }

        return parts.joined(separator: ", ")
    }
}
