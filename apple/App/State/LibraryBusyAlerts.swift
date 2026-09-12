import Foundation
import UserNotifications
import ZotEatsKit

// Optional Study ping when a library building is actually busy on Waitz.
// Real percent only — never a typical/guessed occupancy. Once per library
// per Irvine day. Default off.

@MainActor
enum LibraryBusyAlerts {
    private static let enabledKey = "zoteats.alerts.libraryBusy"
    private static let notifiedKey = "zoteats.libraryBusyNotified"
    private static let idPrefix = "libbusy:"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func runCheck() async {
        guard isEnabled else { return }
        let facilities: [BusynessPoint]
        do {
            facilities = try await BusynessService().all()
        } catch {
            return
        }

        let dateISO = UCITime.todayISO()
        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedKey) ?? [])
        notified = Set(notified.filter { $0.hasPrefix("\(dateISO)|") })
        let notifiedIDs = Set(
            notified.compactMap { key -> Int? in
                Int(key.split(separator: "|").last.map(String.init) ?? "")
            }
        )

        let spikes = LibraryBusyAlertMath.spikes(
            facilities: facilities,
            alreadyNotifiedIDs: notifiedIDs
        )
        let center = UNUserNotificationCenter.current()
        for point in spikes {
            guard let percent = point.percent else { continue }
            let content = UNMutableNotificationContent()
            content.title = UsefulAlertCopy.libraryBusyTitle(name: point.name)
            content.body = UsefulAlertCopy.libraryBusyBody(percent: percent)
            content.sound = .default
            let link = AnteatsDeepLink.study(facilityID: point.id)
            content.userInfo = [
                "deeplink": link.url.absoluteString,
                "facility": String(point.id),
            ]
            notified.insert("\(dateISO)|\(point.id)")
            try? await center.add(
                UNNotificationRequest(
                    identifier: "\(idPrefix)\(dateISO):\(point.id)",
                    content: content,
                    trigger: nil
                )
            )
        }
        UserDefaults.standard.set(Array(notified).sorted(), forKey: notifiedKey)
    }
}
