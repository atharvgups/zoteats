import Foundation

/// Pure planning logic for "tell me when this spot opens" notifications.
/// The app feeds it today's dining halls and campus venues plus the user's
/// watchlist; it returns concrete fire times for local notifications.
/// Kept in the Kit so the scheduling brain is unit-testable on Linux.
public enum OpeningAlertPlanner {
    /// Next meal window still ahead (start + live API period name + close).
    public struct MealOpening: Sendable, Equatable {
        public let startMinutes: Int
        public let endMinutes: Int?
        public let periodName: String

        public init(startMinutes: Int, endMinutes: Int? = nil, periodName: String) {
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
            self.periodName = periodName
        }
    }

    /// A place the user can watch. `opensAtMinutes` is on the calendar day
    /// identified by `dayOffset` (0 = today, 1 = tomorrow).
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let name: String
        public let opensAtMinutes: Int?
        /// 0 = today (Irvine), 1 = tomorrow — used after "closed for today".
        public let dayOffset: Int
        /// Live dining meal name when known (Brunch, Dinner, …); campus omits.
        public let mealPeriod: String?
        /// Dining meal close (minutes since midnight); campus per-window close.
        public let closesAtMinutes: Int?
        /// Campus continuous hours for that fire day ("7:30 AM – 4:00 PM").
        /// Carried per candidate so today + tomorrow don't clobber one map slot.
        public let hoursSpan: String?
        /// Campus open-window start — disambiguates same-day split schedules in
        /// notification ids (`open:campus:…:450`). Dining omits (uses meal pill).
        public let windowStartMinutes: Int?

        public init(
            id: String,
            name: String,
            opensAtMinutes: Int?,
            dayOffset: Int = 0,
            mealPeriod: String? = nil,
            closesAtMinutes: Int? = nil,
            hoursSpan: String? = nil,
            windowStartMinutes: Int? = nil
        ) {
            self.id = id
            self.name = name
            self.opensAtMinutes = opensAtMinutes
            self.dayOffset = max(0, dayOffset)
            self.mealPeriod = mealPeriod
            self.closesAtMinutes = closesAtMinutes
            self.hoursSpan = hoursSpan
            // Campus defaults the window key to the open minute; dining omits
            // (meal pill already disambiguates).
            if let windowStartMinutes {
                self.windowStartMinutes = windowStartMinutes
            } else if mealPeriod == nil {
                self.windowStartMinutes = opensAtMinutes
            } else {
                self.windowStartMinutes = nil
            }
        }
    }

    public struct PlannedAlert: Sendable, Equatable {
        /// Campus: `open:<placeID>:<dateISO>:<startMinutes>` so split windows
        /// don't overwrite each other. Dining: `…:<canonicalPill>`.
        public let identifier: String
        public let placeID: String
        public let placeName: String
        public let fireDate: Date
        /// Live meal name for titles (nil for campus); deep links canonicalize.
        public let mealPeriod: String?
        /// Tomorrow ISO when the alert fires on a future day; omit for today.
        public let deepLinkDate: String?
        /// Dining / campus window close for "Open until …" body copy.
        public let closesAtMinutes: Int?
        /// Campus continuous hours for the fire day (fallback when no close).
        public let hoursSpan: String?

        public init(
            identifier: String,
            placeID: String,
            placeName: String,
            fireDate: Date,
            mealPeriod: String? = nil,
            deepLinkDate: String? = nil,
            closesAtMinutes: Int? = nil,
            hoursSpan: String? = nil
        ) {
            self.identifier = identifier
            self.placeID = placeID
            self.placeName = placeName
            self.fireDate = fireDate
            self.mealPeriod = mealPeriod
            self.deepLinkDate = deepLinkDate
            self.closesAtMinutes = closesAtMinutes
            self.hoursSpan = hoursSpan
        }
    }

    /// Stable notification id — dining includes the canonical meal pill; campus
    /// includes the window start so morning + afternoon reopens both stay pending.
    public static func alertIdentifier(
        placeID: String,
        dateISO: String,
        mealPeriod: String?,
        windowStartMinutes: Int? = nil
    ) -> String {
        let meal = mealPeriod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !meal.isEmpty {
            return "open:\(placeID):\(dateISO):\(MealPeriodPill.canonical(meal))"
        }
        if let start = windowStartMinutes {
            return "open:\(placeID):\(dateISO):\(start)"
        }
        return "open:\(placeID):\(dateISO)"
    }

    /// How long after a meal/window open we still fire a one-shot catch-up
    /// when BG / board publish landed late (missed the exact open minute).
    public static let openCatchUpGraceMinutes = 20

    /// Alerts for every watched place that opens later today **or** tomorrow
    /// (remaining meals while already open, or morning after today's windows end).
    /// Today candidates whose open already passed only schedule when still
    /// within `openCatchUpGraceMinutes` of open and before close (late BG).
    public static func plan(
        candidates: [Candidate],
        watchedIDs: Set<String>,
        now: Date = Date()
    ) -> [PlannedAlert] {
        let nowMinutes = PacificTime.nowMinutes(now: now)
        let calendar = PacificTime.calendar
        let startOfToday = calendar.startOfDay(for: now)

        return candidates.compactMap { candidate -> PlannedAlert? in
            guard watchedIDs.contains(candidate.id),
                  let opensAt = candidate.opensAtMinutes
            else { return nil }

            if candidate.dayOffset == 0 {
                if opensAt <= nowMinutes {
                    // Catch-up: open already started — only while still serving
                    // and within grace of the open minute (late publish / BG).
                    guard let closesAt = candidate.closesAtMinutes,
                          nowMinutes < closesAt,
                          nowMinutes - opensAt <= openCatchUpGraceMinutes
                    else { return nil }
                }
            }

            guard let day = calendar.date(byAdding: .day, value: candidate.dayOffset, to: startOfToday)
            else { return nil }
            let fireDate = day.addingTimeInterval(TimeInterval(opensAt * 60))
            // Identifier keys off the fire-day ISO so an evening reschedule
            // for tomorrow replaces the same slot after midnight.
            let dateISO = PacificTime.todayISO(now: fireDate)
            // Keep live meal names (Brunch / Limited Dinner) for notification
            // titles; OpeningAlerts canonicalizes only the Eat deep-link pill.
            let windowStart = candidate.mealPeriod == nil ? candidate.windowStartMinutes : nil
            return PlannedAlert(
                identifier: alertIdentifier(
                    placeID: candidate.id,
                    dateISO: dateISO,
                    mealPeriod: candidate.mealPeriod,
                    windowStartMinutes: windowStart
                ),
                placeID: candidate.id,
                placeName: candidate.name,
                fireDate: fireDate,
                mealPeriod: candidate.mealPeriod,
                deepLinkDate: candidate.dayOffset >= 1 ? dateISO : nil,
                closesAtMinutes: candidate.closesAtMinutes,
                hoursSpan: candidate.hoursSpan
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// A dining hall's next *reopen* today: earliest meal start still ahead,
    /// but nil while a period is being served (hall is already open).
    public static func nextOpening(periods: [MealPeriodWindow], nowMinutes: Int) -> Int? {
        let openNow = periods.contains {
            guard let start = $0.startMinutes, let end = $0.endMinutes else { return false }
            return nowMinutes >= start && nowMinutes < end
        }
        return openNow ? nil : followingOpening(periods: periods, nowMinutes: nowMinutes)
    }

    /// Earliest meal start still ahead today — even while lunch/dinner is
    /// already being served. Used so watching during lunch still schedules dinner.
    public static func followingOpening(periods: [MealPeriodWindow], nowMinutes: Int) -> Int? {
        followingMeal(periods: periods, nowMinutes: nowMinutes)?.startMinutes
    }

    /// Same as `followingOpening`, plus the live meal name and close for copy.
    public static func followingMeal(
        periods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> MealOpening? {
        followingMeals(periods: periods, nowMinutes: nowMinutes).first
    }

    /// Every timed meal still ahead today (Breakfast + Lunch + Dinner), sorted
    /// by start — so Opening Alerts can pre-arm the full chain without waiting
    /// on a post-Breakfast BG refresh that often lands after Lunch opens.
    public static func followingMeals(
        periods: [MealPeriodWindow],
        nowMinutes: Int
    ) -> [MealOpening] {
        allTimedMeals(periods: periods).filter { $0.startMinutes > nowMinutes }
    }

    /// Meals already open but still inside the catch-up grace window — late
    /// Lunch/Dinner publish or BG can still deliver "just opened" once.
    public static func recentlyOpenedMeals(
        periods: [MealPeriodWindow],
        nowMinutes: Int,
        graceMinutes: Int = openCatchUpGraceMinutes
    ) -> [MealOpening] {
        allTimedMeals(periods: periods).filter { meal in
            guard meal.startMinutes <= nowMinutes else { return false }
            guard nowMinutes - meal.startMinutes <= graceMinutes else { return false }
            guard let end = meal.endMinutes, nowMinutes < end else { return false }
            return true
        }
    }

    /// Campus open windows already started but still within catch-up grace.
    public static func recentlyOpenedWindows(
        windows: [CampusHoursWindow],
        nowMinutes: Int,
        graceMinutes: Int = openCatchUpGraceMinutes
    ) -> [CampusHoursWindow] {
        windows.filter { window in
            guard window.startMinutes <= nowMinutes else { return false }
            guard nowMinutes - window.startMinutes <= graceMinutes else { return false }
            guard nowMinutes < window.endMinutes else { return false }
            return true
        }
    }

    /// Every timed meal on a day of periods (Breakfast + Lunch + Dinner), sorted
    /// by start — used to pre-arm tomorrow's full chain overnight so Lunch /
    /// Dinner don't depend on a morning BG that may land after they open.
    public static func allTimedMeals(periods: [MealPeriodWindow]) -> [MealOpening] {
        periods
            .compactMap { period -> MealOpening? in
                guard let start = period.startMinutes else { return nil }
                return MealOpening(
                    startMinutes: start,
                    endMinutes: period.endMinutes,
                    periodName: period.name
                )
            }
            .sorted { $0.startMinutes < $1.startMinutes }
    }

    /// Earliest meal start on a day of periods (e.g. tomorrow's breakfast).
    public static func earliestOpening(periods: [MealPeriodWindow]) -> Int? {
        earliestMeal(periods: periods)?.startMinutes
    }

    /// Same as `earliestOpening`, plus the live meal name and close for copy.
    public static func earliestMeal(periods: [MealPeriodWindow]) -> MealOpening? {
        allTimedMeals(periods: periods).first
    }

    /// Fri→Mon (and other beyond-tomorrow) Opening Alert Candidates from a
    /// fetched next-open board only — never invent a single chrome open when
    /// `mealPeriods` is empty (mirror tomorrow's allTimedMeals-only arming).
    public static func nextOpenDiningCandidates(
        placeID: String,
        name: String,
        opensTomorrowAtMinutes: Int?,
        opensNextDayOffset: Int?,
        nextOpenPeriods: [MealPeriodWindow]
    ) -> [Candidate] {
        guard opensTomorrowAtMinutes == nil,
              let offset = opensNextDayOffset
        else { return [] }
        return allTimedMeals(periods: nextOpenPeriods).map { meal in
            Candidate(
                id: placeID,
                name: name,
                opensAtMinutes: meal.startMinutes,
                dayOffset: offset,
                mealPeriod: meal.periodName,
                closesAtMinutes: meal.endMinutes
            )
        }
    }
}
