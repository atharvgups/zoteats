import Foundation
import Observation
import ZotEatsKit

// Plate Builder: tap dishes onto today's plate and watch calories + protein
// add up. Local-only (UserDefaults), resets each Irvine day, no accounts.

@MainActor
@Observable
final class PlateStore {
    private static let storageKey = "zoteats.plate"

    private struct Saved: Codable {
        let dateISO: String
        let entries: [PlateEntry]
    }

    private(set) var entries: [PlateEntry] = []

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.dateISO == Self.todayISO()
        else { return }
        entries = saved.entries
    }

    var isEmpty: Bool { entries.isEmpty }
    var totalCalories: Int { PlateTotals.calories(from: entries) }
    var totalProteinG: Int { PlateTotals.proteinGrams(from: entries) }

    func isOnPlate(_ dishName: String) -> Bool {
        entries.contains { $0.dishName == dishName }
    }

    /// One tap adds, a second tap removes — no separate delete mode needed.
    func toggle(_ item: MenuItem) {
        if let index = entries.firstIndex(where: { $0.dishName == item.name }) {
            entries.remove(at: index)
        } else {
            entries.append(PlateEntry(
                dishName: item.name,
                calories: item.calories,
                proteinG: item.nutrition?.proteinG
            ))
        }
        Haptics.soft()
        persist()
    }

    func remove(_ entry: PlateEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        let saved = Saved(dateISO: Self.todayISO(), entries: entries)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func todayISO() -> String {
        UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
    }
}
