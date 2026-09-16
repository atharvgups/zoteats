import Foundation

/// VoiceOver for Study facility card chrome — one announcement for open/closed
/// crowding plus the same "Updated …" freshness sighted users see.
public enum StudyFacilityAccessibilityLabel {
    public static func label(
        name: String,
        isOpen: Bool,
        percent: Int?,
        levelLabel: String?,
        peopleCount: Int?,
        capacity: Int?,
        updatedRelative: String? = nil,
        hoursSummary: String? = nil,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = [trimmed.isEmpty ? "Library" : trimmed]
        let level = levelLabel?.trimmingCharacters(in: .whitespacesAndNewlines)

        if StudyFacilityCrowding.showsLiveCrowding(isOpen: isOpen) {
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

            if let openLine = StudyIdleCopy.facilityOpenDetail(hoursSummary: hoursSummary) {
                parts.append(openLine)
            }
        } else {
            parts.append("closed")
            parts.append(
                StudyIdleCopy.facilityClosedDetail(
                    hoursSummary: hoursSummary,
                    nowMinutes: nowMinutes
                )
            )
        }

        if let updated = updatedRelative?.trimmingCharacters(in: .whitespacesAndNewlines),
           !updated.isEmpty {
            parts.append("Updated \(updated)")
        }

        return parts.joined(separator: ", ")
    }
}
