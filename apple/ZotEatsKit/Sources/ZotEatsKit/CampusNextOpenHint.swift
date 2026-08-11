import Foundation

/// Soonest reopen among closed campus spots — powers empty Open Now copy
/// on the Campus tab and Campus Open widget.
public enum CampusNextOpenHint {
    public struct Hint: Equatable, Sendable {
        public let placeID: String
        public let placeName: String
        public let opensAtMinutes: Int
        public let isTomorrow: Bool

        public init(
            placeID: String,
            placeName: String,
            opensAtMinutes: Int,
            isTomorrow: Bool
        ) {
            self.placeID = placeID
            self.placeName = placeName
            self.opensAtMinutes = opensAtMinutes
            self.isTomorrow = isTomorrow
        }

        /// Short display name without location suffix ("Starbucks @ …" → "Starbucks").
        public var shortName: String {
            let separators = [" @ ", " at ", " – ", " - "]
            for sep in separators {
                if let range = placeName.range(of: sep, options: .caseInsensitive) {
                    return String(placeName[..<range.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return placeName
        }

        public var line: String {
            let time = UCITime.format(minutes: opensAtMinutes)
            if isTomorrow {
                return "\(shortName) opens tomorrow at \(time)"
            }
            return "\(shortName) opens at \(time)"
        }
    }

    /// Prefer today's next open; else tomorrow's earliest. Skips open venues.
    public static func best(from places: [CampusPlace]) -> Hint? {
        var todayCandidates: [(place: CampusPlace, minutes: Int)] = []
        var tomorrowCandidates: [(place: CampusPlace, minutes: Int)] = []

        for place in places where !place.openNow {
            if let minutes = place.opensAtMinutes {
                todayCandidates.append((place, minutes))
            } else if let minutes = place.opensTomorrowAtMinutes {
                tomorrowCandidates.append((place, minutes))
            }
        }

        if let pick = earliest(todayCandidates) {
            return Hint(
                placeID: pick.place.id,
                placeName: pick.place.name,
                opensAtMinutes: pick.minutes,
                isTomorrow: false
            )
        }
        if let pick = earliest(tomorrowCandidates) {
            return Hint(
                placeID: pick.place.id,
                placeName: pick.place.name,
                opensAtMinutes: pick.minutes,
                isTomorrow: true
            )
        }
        return nil
    }

    private static func earliest(
        _ candidates: [(place: CampusPlace, minutes: Int)]
    ) -> (place: CampusPlace, minutes: Int)? {
        candidates.min { lhs, rhs in
            if lhs.minutes != rhs.minutes {
                return lhs.minutes < rhs.minutes
            }
            return lhs.place.name.localizedCaseInsensitiveCompare(rhs.place.name) == .orderedAscending
        }
    }
}
