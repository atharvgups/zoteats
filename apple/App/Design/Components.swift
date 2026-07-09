import SwiftUI
import ZotEatsKit

// Shared building blocks used across Dining, Gym, and Busyness.

// MARK: - Open/closed status pill

struct StatusPill: View {
    let isOpen: Bool
    var openText: String = "Open"
    var closedText: String = "Closed"

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isOpen ? Color.openGreen : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(isOpen ? openText : closedText)
                .font(ZotFont.pill)
                .foregroundStyle(isOpen ? Color.openGreen : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isOpen ? Color.openGreen : Color.secondary).opacity(0.12), in: Capsule())
        .accessibilityLabel(isOpen ? openText : closedText)
    }
}

// MARK: - Small colored tag chip (diet tags / allergens)

struct TagChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Horizontal selectable pill row

struct PillRow<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item?
    var allowsDeselect = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selection == item
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selection = (isSelected && allowsDeselect) ? nil : item
                        }
                        Haptics.selection()
                    } label: {
                        Text(title(item))
                            .font(ZotFont.pill)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? AnyShapeStyle(Color.uciBlue) : AnyShapeStyle(Color.card),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                            .overlay(Capsule().strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Occupancy bar with level color

struct OccupancyBar: View {
    let percent: Int?
    let level: BusynessLevel
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if let percent {
                    Capsule()
                        .fill(level.color.gradient)
                        .frame(width: max(height, geo.size.width * CGFloat(percent) / 100))
                }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.6), value: percent)
        .accessibilityLabel(percent.map { "\($0) percent full" } ?? "No occupancy data")
    }
}

// MARK: - Loading / empty / error states

struct SkeletonCard: View {
    var height: CGFloat = 92
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.quaternary)
            .frame(height: height)
            .opacity(pulse ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(ZotFont.sectionTitle)
            Text(message)
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .tint(.uciBlue)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
}

// MARK: - Screen header

struct ScreenHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ZotFont.hero())
            if let subtitle {
                Text(subtitle)
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func soft() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

// MARK: - Relative "updated X ago" text that stays fresh

struct UpdatedAgoText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text("Updated \(relative(to: context.date))")
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func relative(to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
