import WidgetKit
import SwiftUI
import ActivityKit
import ZotEatsKit

// ZotEats home-screen widget: dining hall status at a glance — open state with
// closes-in/opens-at intelligence and typical occupancy — plus the quietest
// library on the medium size. Refreshes roughly every 20 minutes.

@main
struct ZotEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        DiningStatusWidget()
        MealCountdownActivity()
    }
}

// MARK: - "Meal ends soon" Live Activity

private let activityBlue = Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
private let activityGold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

struct MealCountdownActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MealActivityAttributes.self) { context in
            // Lock screen banner.
            HStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(activityGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.hallName)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(context.attributes.period) ends in")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
                Spacer()
                Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .foregroundStyle(activityGold)
            }
            .padding(16)
            .activityBackgroundTint(activityBlue)
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(activityGold)
                        Text(context.attributes.hallName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 84)
                        .foregroundStyle(activityGold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.period) is wrapping up — zot while you can")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now, context.state.endsAt), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(activityGold)
            } minimal: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(activityGold)
            }
        }
    }
}

// MARK: - Timeline

struct DiningStatusEntry: TimelineEntry {
    let date: Date
    let halls: [HallStatus]
    let quietest: (name: String, percent: Int)?

    struct HallStatus {
        let name: String
        let statusText: String
        let isOpen: Bool
        let occupancy: Int?
    }
}

struct DiningStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningStatusEntry {
        DiningStatusEntry(
            date: .now,
            halls: [
                .init(name: "The Anteatery", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 72),
                .init(name: "Brandywine", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 65),
            ],
            quietest: (name: "Science Library", percent: 12)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DiningStatusEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        // WidgetKit's completion closures aren't Sendable; box them to cross
        // into the async task under Swift 6 strict concurrency.
        let deliver = UncheckedSendableBox(completion)
        Task { deliver.value(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiningStatusEntry>) -> Void) {
        let deliver = UncheckedSendableBox(completion)
        Task {
            let entry = await fetchEntry()
            deliver.value(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(20 * 60))))
        }
    }

    private func fetchEntry() async -> DiningStatusEntry {
        let locations = await DiningService().locations()
        let nowMinutes = UCITime.nowMinutes()

        let halls = locations.map { location -> DiningStatusEntry.HallStatus in
            let status: String
            switch location.openState(nowMinutes: nowMinutes) {
            case .open(let period, let closesAt):
                status = "\(period) · closes \(UCITime.format(minutes: closesAt % (24 * 60)))"
            case .openingLater(let period, let opensAt):
                status = "\(period) at \(UCITime.format(minutes: opensAt))"
            case .closedForToday:
                status = "Closed for today"
            case .unknown:
                status = location.todayHours ?? "Hours unavailable"
            }
            let estimate = TypicalBusyness.dining(periods: location.periods)
            return .init(
                name: location.name,
                statusText: status,
                isOpen: location.openNow,
                occupancy: FeatureFlags.diningHallOccupancy && location.openNow && estimate.percentNow > 0
                    ? estimate.percentNow : nil
            )
        }

        let quietest = (try? await BusynessService().all())?
            .filter { $0.isOpen && $0.percent != nil }
            .min { ($0.percent ?? 101) < ($1.percent ?? 101) }
            .map { (name: $0.name, percent: $0.percent ?? 0) }

        return DiningStatusEntry(date: .now, halls: halls, quietest: quietest)
    }
}

/// Carries a non-Sendable value across a concurrency boundary we know is safe
/// (WidgetKit invokes its completions in a thread-safe manner).
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Widget

struct DiningStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZotEatsDiningStatus", provider: DiningStatusProvider()) { entry in
            DiningStatusView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0 / 255, green: 100 / 255, blue: 164 / 255)
                }
        }
        .configurationDisplayName("Dining Halls")
        .description("Open status, hours, and how busy the halls usually are right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DiningStatusView: View {
    let entry: DiningStatusEntry
    @Environment(\.widgetFamily) private var family

    private let gold = Color(red: 255 / 255, green: 210 / 255, blue: 0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 9) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text("ZOTEATS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                Spacer()
            }
            .foregroundStyle(gold)

            ForEach(entry.halls.prefix(family == .systemSmall ? 2 : 3), id: \.name) { hall in
                hallRow(hall)
            }

            if family == .systemMedium, let quietest = entry.quietest {
                Divider()
                    .overlay(.white.opacity(0.25))
                HStack(spacing: 5) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(gold)
                    Text("Quietest: \(quietest.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text("\(quietest.percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func hallRow(_ hall: DiningStatusEntry.HallStatus) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Circle()
                    .fill(hall.isOpen ? Color.green : Color.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(shortName(hall.name))
                    .font(.system(size: family == .systemSmall ? 12 : 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 3)
                if let occupancy = hall.occupancy {
                    Text("\(occupancy)%")
                        .font(.system(size: family == .systemSmall ? 12 : 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(gold)
                }
            }
            Text(hall.statusText)
                .font(.system(size: family == .systemSmall ? 10 : 11))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(hall.name), \(hall.statusText)\(hall.occupancy.map { ", \($0) percent occupancy" } ?? "")"
        )
    }

    /// "The Anteatery" -> "Anteatery" for tight widget rows.
    private func shortName(_ name: String) -> String {
        name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
    }
}

#Preview(as: .systemMedium) {
    DiningStatusWidget()
} timeline: {
    DiningStatusEntry(
        date: .now,
        halls: [
            .init(name: "The Anteatery", statusText: "Dinner · closes 8 PM", isOpen: true, occupancy: 72),
            .init(name: "Brandywine", statusText: "Dinner at 4:30 PM", isOpen: false, occupancy: nil),
        ],
        quietest: (name: "Science Library", percent: 12)
    )
}
