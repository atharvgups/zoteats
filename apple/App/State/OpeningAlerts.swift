import Foundation
import UserNotifications
import ZotEatsKit

// Useful local alerts: dining meal start / closing soon, campus-favorite
// open/close, plus a separate Waitz library-busy check. Quiet defaults — every
// type is off until the user flips a Settings switch. Dining uses the hall
// watchlist (Anteatery if none picked). Campus uses hearted places with hours.
// No servers — iOS fires scheduled banners even if the app stays closed.

@MainActor
enum OpeningAlerts {
    private static let watchedKey = "zoteats.openingAlertPlaces"
    private static let diningOpenKey = "zoteats.alerts.diningOpen"
    private static let diningClosingKey = "zoteats.alerts.diningClosing"
    private static let campusHoursKey = "zoteats.alerts.campusHours"
    private static let openPrefix = "open:"
    private static let closePrefix = "close:"

    /// Dining hall ids only (`dining:<hallID>`). Campus hearts live elsewhere.
    static var watchedIDs: Set<String> {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: watchedKey) ?? []
            return Set(stored.filter { $0.hasPrefix("dining:") })
        }
        set {
            UserDefaults.standard.set(
                Array(newValue.filter { $0.hasPrefix("dining:") }).sorted(),
                forKey: watchedKey
            )
        }
    }

    static var diningOpenEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: diningOpenKey) }
        set { UserDefaults.standard.set(newValue, forKey: diningOpenKey) }
    }

    static var diningClosingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: diningClosingKey) }
        set { UserDefaults.standard.set(newValue, forKey: diningClosingKey) }
    }

    static var campusHoursEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: campusHoursKey) }
        set { UserDefaults.standard.set(newValue, forKey: campusHoursKey) }
    }

    static var anyEnabled: Bool {
        diningOpenEnabled || diningClosingEnabled || campusHoursEnabled || LibraryBusyAlerts.isEnabled
    }

    static func isWatching(_ id: String) -> Bool {
        watchedIDs.contains(id)
    }

    static func setWatching(_ id: String, _ watching: Bool) {
        guard id.hasPrefix("dining:") else { return }
        var ids = watchedIDs
        if watching { ids.insert(id) } else { ids.remove(id) }
        watchedIDs = ids
        Task { await refreshSchedules() }
    }

    /// Watched halls, or today's default (Anteatery) when the list is empty.
    static func diningWatchIDs() -> Set<String> {
        let picked = watchedIDs
        if !picked.isEmpty { return picked }
        guard let fallback = HallDirectory.fallbackIDs.first else { return [] }
        return ["dining:\(fallback)"]
    }

    static func campusWatchIDs() -> Set<String> {
        Set(SharedDefaults.favoriteCampusPlaceIDs().map { "campus:\($0)" })
    }

    /// Re-plans open + closing-soon banners from fresh hours.
    static func refreshSchedules() async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
        let ours = pending.filter {
            $0.hasPrefix(openPrefix) || $0.hasPrefix(closePrefix) || $0.hasPrefix("menudrop:")
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let deliveredIDs = Set(
            await center.deliveredNotifications()
                .map(\.request.identifier)
                .filter { $0.hasPrefix(openPrefix) || $0.hasPrefix(closePrefix) }
        )

        let wantDining = diningOpenEnabled || diningClosingEnabled
        let wantCampus = campusHoursEnabled
        guard wantDining || wantCampus else { return }

        var diningCandidates: [OpeningAlertPlanner.Candidate] = []
        var campusCandidates: [OpeningAlertPlanner.Candidate] = []

        let dining = DiningService()
        let nowMinutes = UCITime.nowMinutes()
        let tomorrowISO = UCITime.upcomingDays(count: 2).dropFirst().first?.isoDate

        if wantDining {
            for hall in await dining.locations() {
                let id = "dining:\(hall.id)"
                for meal in OpeningAlertPlanner.followingMeals(
                    periods: hall.periods, nowMinutes: nowMinutes
                ) {
                    diningCandidates.append(.init(
                        id: id,
                        name: hall.name,
                        opensAtMinutes: meal.startMinutes,
                        dayOffset: 0,
                        mealPeriod: meal.periodName,
                        closesAtMinutes: meal.endMinutes
                    ))
                }
                for meal in OpeningAlertPlanner.recentlyOpenedMeals(
                    periods: hall.periods, nowMinutes: nowMinutes
                ) {
                    diningCandidates.append(.init(
                        id: id,
                        name: hall.name,
                        opensAtMinutes: meal.startMinutes,
                        dayOffset: 0,
                        mealPeriod: meal.periodName,
                        closesAtMinutes: meal.endMinutes
                    ))
                }
                if let tomorrowISO {
                    let periods = await dining.mealPeriods(for: hall.id, dateISO: tomorrowISO)
                    for meal in OpeningAlertPlanner.allTimedMeals(periods: periods) {
                        diningCandidates.append(.init(
                            id: id,
                            name: hall.name,
                            opensAtMinutes: meal.startMinutes,
                            dayOffset: 1,
                            mealPeriod: meal.periodName,
                            closesAtMinutes: meal.endMinutes
                        ))
                    }
                }
                if hall.opensTomorrowAtMinutes == nil {
                    let nextPeriods: [MealPeriodWindow]
                    if let nextISO = hall.opensNextDateISO {
                        nextPeriods = await dining.mealPeriods(for: hall.id, dateISO: nextISO)
                    } else {
                        nextPeriods = []
                    }
                    diningCandidates.append(contentsOf: OpeningAlertPlanner.nextOpenDiningCandidates(
                        placeID: id,
                        name: hall.name,
                        opensTomorrowAtMinutes: hall.opensTomorrowAtMinutes,
                        opensNextDayOffset: hall.opensNextDayOffset,
                        nextOpenPeriods: nextPeriods
                    ))
                }
            }
        }

        if wantCampus {
            for place in (try? await CampusService().places()) ?? [] {
                let id = "campus:\(place.id)"
                for window in place.upcomingWindows {
                    campusCandidates.append(.init(
                        id: id,
                        name: place.name,
                        opensAtMinutes: window.startMinutes,
                        dayOffset: 0,
                        closesAtMinutes: window.endMinutes,
                        windowStartMinutes: window.startMinutes
                    ))
                }
                if let start = place.currentOpenStartMinutes,
                   let end = place.closesAtMinutes,
                   nowMinutes - start <= OpeningAlertPlanner.openCatchUpGraceMinutes,
                   nowMinutes < end {
                    campusCandidates.append(.init(
                        id: id,
                        name: place.name,
                        opensAtMinutes: start,
                        dayOffset: 0,
                        closesAtMinutes: end,
                        hoursSpan: place.todayHours,
                        windowStartMinutes: start
                    ))
                }
                for window in place.tomorrowOpenWindows {
                    campusCandidates.append(.init(
                        id: id,
                        name: place.name,
                        opensAtMinutes: window.startMinutes,
                        dayOffset: 1,
                        closesAtMinutes: window.endMinutes,
                        hoursSpan: place.tomorrowHours,
                        windowStartMinutes: window.startMinutes
                    ))
                }
                if let offset = place.opensNextDayOffset {
                    for window in place.nextOpenWindows {
                        campusCandidates.append(.init(
                            id: id,
                            name: place.name,
                            opensAtMinutes: window.startMinutes,
                            dayOffset: offset,
                            closesAtMinutes: window.endMinutes,
                            hoursSpan: place.nextOpenHours,
                            windowStartMinutes: window.startMinutes
                        ))
                    }
                }
            }
        }

        var planned: [OpeningAlertPlanner.PlannedAlert] = []
        let diningIDs = diningWatchIDs()
        let campusIDs = campusWatchIDs()
        if diningOpenEnabled {
            planned.append(contentsOf: OpeningAlertPlanner.plan(
                candidates: diningCandidates, watchedIDs: diningIDs
            ))
        }
        if diningClosingEnabled {
            planned.append(contentsOf: OpeningAlertPlanner.planClosingSoon(
                candidates: diningCandidates, watchedIDs: diningIDs
            ))
        }
        if campusHoursEnabled {
            planned.append(contentsOf: OpeningAlertPlanner.plan(
                candidates: campusCandidates, watchedIDs: campusIDs
            ))
            planned.append(contentsOf: OpeningAlertPlanner.planClosingSoon(
                candidates: campusCandidates, watchedIDs: campusIDs
            ))
        }

        for alert in planned {
            if deliveredIDs.contains(alert.identifier) { continue }
            try? await center.add(
                UNNotificationRequest(
                    identifier: alert.identifier,
                    content: content(for: alert),
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: max(1, alert.fireDate.timeIntervalSinceNow),
                        repeats: false
                    )
                )
            )
        }
    }

    private static func content(for alert: OpeningAlertPlanner.PlannedAlert) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if alert.isClosing {
            content.title = UsefulAlertCopy.closingSoonTitle(
                placeName: alert.placeName,
                mealPeriod: alert.mealPeriod
            )
            if let close = alert.closesAtMinutes {
                content.body = UsefulAlertCopy.closingSoonBody(closesAtMinutes: close)
            } else {
                content.body = "Last call — this window is about to end."
            }
        } else if let meal = alert.mealPeriod {
            let display = MealPeriodDisplay.label(live: meal)
            content.title = "\(alert.placeName) · \(display) just opened"
            content.body = OpeningAlertCopy.body(
                openUntilMinutes: alert.closesAtMinutes,
                hoursSpan: alert.hoursSpan
            )
        } else {
            content.title = "\(alert.placeName) just opened"
            content.body = OpeningAlertCopy.body(
                openUntilMinutes: alert.closesAtMinutes,
                hoursSpan: alert.hoursSpan
            )
        }
        content.sound = .default
        let link: AnteatsDeepLink = {
            if alert.placeID.hasPrefix("campus:") {
                return .campus(placeID: String(alert.placeID.dropFirst("campus:".count)))
            }
            if alert.placeID.hasPrefix("dining:") {
                let pill = alert.mealPeriod.map { MealPeriodPill.canonical($0) }
                return .eat(
                    hall: String(alert.placeID.dropFirst("dining:".count)),
                    period: pill,
                    date: alert.deepLinkDate
                )
            }
            return .eat()
        }()
        var userInfo: [String: String] = [
            "deeplink": link.url.absoluteString,
            "place": alert.placeID,
        ]
        if alert.placeID.hasPrefix("dining:") {
            let hall = String(alert.placeID.dropFirst("dining:".count))
            userInfo["hallID"] = hall
            if let period = link.period {
                userInfo["period"] = period
            }
            if let date = link.date {
                userInfo["date"] = date
            }
        }
        content.userInfo = userInfo
        return content
    }
}
