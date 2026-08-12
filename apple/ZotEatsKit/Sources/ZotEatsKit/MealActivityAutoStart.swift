import Foundation

/// Pick a hall meal in its final auto-start window for Live Activity.
/// App-level (foreground + BG) so Auto meal countdown works off the Eat tab.
public enum MealActivityAutoStart {
    public struct Candidate: Equatable, Sendable {
        public let hallID: String
        public let hallName: String
        public let livePeriodName: String
        public let startMinutes: Int
        public let endMinutes: Int
        public let opensTomorrowPeriod: String?
        public let timedPeriods: [MealPeriodWindow]

        public init(
            hallID: String,
            hallName: String,
            livePeriodName: String,
            startMinutes: Int,
            endMinutes: Int,
            opensTomorrowPeriod: String?,
            timedPeriods: [MealPeriodWindow]
        ) {
            self.hallID = hallID
            self.hallName = hallName
            self.livePeriodName = livePeriodName
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
            self.opensTomorrowPeriod = opensTomorrowPeriod
            self.timedPeriods = timedPeriods
        }
    }

    /// Soonest-ending hall meal currently inside the T−45 auto-start window.
    public static func pick(
        locations: [DiningLocation],
        nowMinutes: Int,
        alreadyTracking: Bool,
        autoEnabled: Bool
    ) -> Candidate? {
        guard autoEnabled, !alreadyTracking else { return nil }

        var candidates: [Candidate] = []
        for location in locations {
            let pills = DiningService.primaryPeriods(from: location.availablePeriods)
            for pill in pills {
                guard let window = MealTrackWindow.resolve(
                    pill: pill,
                    timedPeriods: location.periods,
                    availablePeriods: location.availablePeriods
                ) else { continue }
                guard MealTrackMath.shouldAutoStart(
                    nowMinutes: nowMinutes,
                    startMinutes: window.startMinutes,
                    endMinutes: window.endMinutes,
                    alreadyTracking: false,
                    autoEnabled: true
                ) else { continue }
                candidates.append(
                    Candidate(
                        hallID: location.id,
                        hallName: location.name,
                        livePeriodName: window.livePeriodName,
                        startMinutes: window.startMinutes,
                        endMinutes: window.endMinutes,
                        opensTomorrowPeriod: location.opensTomorrowPeriod,
                        timedPeriods: location.periods
                    )
                )
            }
        }

        return candidates.min(by: { $0.endMinutes < $1.endMinutes })
    }

    /// Pacific minutes when each timed meal enters its auto-start window (end − 45).
    public static func wrapUpAimMinutes(locations: [DiningLocation]) -> [Int] {
        var aims = Set<Int>()
        for location in locations {
            for period in location.periods {
                guard let start = period.startMinutes,
                      let end = period.endMinutes,
                      end > start
                else { continue }
                let autoAt = end - MealTrackMath.autoStartWindowMinutes
                if autoAt > start {
                    aims.insert(autoAt)
                }
            }
        }
        return aims.sorted()
    }

    /// Pacific minutes when each timed meal opens — Favorite Alerts BG aims so
    /// Brunch / early Dinner hearts don't wait on fixed 11:15 / 16:15 walls.
    public static func mealOpenAimMinutes(locations: [DiningLocation]) -> [Int] {
        var aims = Set<Int>()
        for location in locations {
            for period in location.periods {
                guard let start = period.startMinutes else { continue }
                aims.insert(start)
            }
        }
        return aims.sorted()
    }
}
