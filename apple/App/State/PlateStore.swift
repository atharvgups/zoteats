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
    /// Irvine calendar day the in-memory plate belongs to.
    private var dateISO: String

    init() {
        let today = Self.todayISO()
        dateISO = today
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        guard let saved = try? JSONDecoder().decode(Saved.self, from: data) else {
            // Corrupt blob — drop it so a later launch can't resurrect junk.
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }

        entries = PlateDayMath.entriesIfCurrentDay(
            savedDateISO: saved.dateISO,
            entries: saved.entries,
            todayISO: today
        )
        if PlateDayMath.shouldClear(savedDateISO: saved.dateISO, todayISO: today) {
            // Drop yesterday's blob so a later crash mid-day can't resurrect it.
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    var isEmpty: Bool { entries.isEmpty }
    var totalCalories: Int { PlateTotals.calories(from: entries) }
    var totalProteinG: Int { PlateTotals.proteinGrams(from: entries) }
    var servingCount: Int { PlateTotals.servingCount(from: entries) }

    func quantity(for dishName: String) -> Int {
        entries.first { $0.dishName == dishName }?.quantity ?? 0
    }

    /// Call on foreground / Eat appear — app-lifetime store survives past midnight.
    func ensureCurrentDay() {
        let today = Self.todayISO()
        guard dateISO != today else { return }
        entries = []
        dateISO = today
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    func isOnPlate(_ dishName: String) -> Bool {
        entries.contains { $0.dishName == dishName }
    }

    /// Add dishes that aren't already on today's plate (Track Meal favorites).
    func addMissing(_ items: [MenuItem]) {
        guard !items.isEmpty else { return }
        ensureCurrentDay()
        var added = false
        for item in items where !isOnPlate(item.name) {
            entries.append(PlateEntry(
                dishName: item.name,
                calories: item.calories,
                proteinG: item.nutrition?.proteinG
            ))
            added = true
        }
        if added {
            Haptics.soft()
            persist()
        }
    }

    /// Tap + to add the first serving, or another serving of the same dish.
    func add(_ item: MenuItem) {
        ensureCurrentDay()
        if let index = entries.firstIndex(where: { $0.dishName == item.name }) {
            entries[index] = entries[index].updatingQuantity(
                PlateQuantity.incremented(entries[index].quantity)
            )
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

    func increment(_ entry: PlateEntry) {
        ensureCurrentDay()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entries[index].updatingQuantity(
            PlateQuantity.incremented(entries[index].quantity)
        )
        Haptics.soft()
        persist()
    }

    func decrement(_ entry: PlateEntry) {
        ensureCurrentDay()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        if let next = PlateQuantity.decremented(entries[index].quantity) {
            entries[index] = entries[index].updatingQuantity(next)
        } else {
            entries.remove(at: index)
        }
        Haptics.soft()
        persist()
    }

    func remove(_ entry: PlateEntry) {
        ensureCurrentDay()
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        dateISO = Self.todayISO()
        persist()
    }

    private func persist() {
        dateISO = Self.todayISO()
        if PlateDayMath.shouldDropStorage(entries: entries) {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }
        let saved = Saved(dateISO: dateISO, entries: entries)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func todayISO() -> String {
        UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
    }
}
