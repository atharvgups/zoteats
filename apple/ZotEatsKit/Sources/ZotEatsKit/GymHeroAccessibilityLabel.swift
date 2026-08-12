import Foundation

/// VoiceOver for the in-app Gym hero — one announcement with open/closed,
/// crowding, hours, and live Updated freshness (parity with Study facility).
public enum GymHeroAccessibilityLabel {
    public static func label(
        isOpen: Bool,
        hoursLine: String,
        percent: Int?,
        levelLabel: String?,
        isTypical: Bool,
        peopleCount: Int?,
        idleMessage: String?,
        updatedRelative: String? = nil
    ) -> String {
        let hours = hoursLine.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = ["ARC", "Anteater Recreation Center"]

        if isOpen {
            parts.append("open")
        } else if !hours.lowercased().hasPrefix("closed") {
            parts.append("closed")
        }

        if let percent {
            var crowd = "\(percent) percent full"
            if let levelLabel {
                let level = levelLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !level.isEmpty { crowd += ", \(level)" }
            }
            crowd += isTypical ? ", typical estimate" : ", live"
            parts.append(crowd)
            if let peopleCount {
                parts.append("\(peopleCount) people")
            }
        } else if let idle = idleMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !idle.isEmpty,
                  !isRedundantIdle(idle: idle, isOpen: isOpen, hoursLine: hours) {
            parts.append(idle)
        }

        if !hours.isEmpty {
            parts.append(hours)
        }

        if let updated = updatedRelative?.trimmingCharacters(in: .whitespacesAndNewlines),
           !updated.isEmpty {
            parts.append("Updated \(updated)")
        }

        return parts.joined(separator: ", ")
    }

    /// "Closed — opens at 6:00 AM" is covered by closed + hoursLine "Opens at 6:00 AM".
    private static func isRedundantIdle(idle: String, isOpen: Bool, hoursLine: String) -> Bool {
        guard !isOpen, !hoursLine.isEmpty else { return false }
        let idleLower = idle.lowercased()
        return idleLower.hasPrefix("closed") && idleLower.contains("opens")
    }
}
