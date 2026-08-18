import SwiftUI
import ZotEatsKit

// Shared building blocks used across Dining, Gym, and Busyness.

// MARK: - Open/closed status pill

struct StatusPill: View {
    let isOpen: Bool
    var openText: String = "Open"
    var closedText: String = "Closed"
    /// Set when the pill sits on a colored (accent/gradient) background.
    var onAccent = false

    private var dotColor: Color {
        if onAccent { return isOpen ? .uciGold : .white.opacity(0.75) }
        return isOpen ? .openGreen : Color.secondary.opacity(0.5)
    }

    private var textColor: Color {
        if onAccent { return .white }
        return isOpen ? .openGreen : .secondary
    }

    private var fillColor: Color {
        if onAccent { return .white.opacity(0.18) }
        return (isOpen ? Color.openGreen : Color.secondary).opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(isOpen ? openText : closedText)
                .font(ZotFont.pill)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fillColor, in: Capsule())
        .accessibilityLabel(isOpen ? openText : closedText)
    }
}

// MARK: - Small colored tag chip (diet tags / allergens)

struct TagChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: zotChipRadius, style: .continuous))
            .foregroundStyle(color)
    }
}

// MARK: - Personal dish rating (1–5)

struct StarRatingControl: View {
    var stars: Int
    var size: CGFloat = 28
    var interactive = true
    var onRate: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: size > 20 ? 8 : 3) {
            ForEach(1...5, id: \.self) { value in
                let star = Image(systemName: value <= stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(value <= stars ? Color.uciGold : Color.inkMuted.opacity(0.45))
                if interactive, let onRate {
                    Button {
                        onRate(value)
                        Haptics.selection()
                    } label: {
                        star.symbolEffect(.bounce, value: stars == value)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(MealReviewAccessibility.starsLabel(value))
                    .accessibilityAddTraits(value == stars ? [.isSelected] : [])
                    .accessibilityIdentifier("dish-star-\(value)")
                } else {
                    star
                }
            }
        }
        .accessibilityElement(children: interactive ? .contain : .ignore)
        .accessibilityLabel(stars > 0 ? MealReviewAccessibility.starsLabel(stars) : "Not rated")
    }
}

// MARK: - Horizontal selectable pill row

struct PillRow<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item?
    var allowsDeselect = false
    /// When true, pills share the row evenly (no horizontal scroll) — used for
    /// Breakfast / Lunch / Dinner so they match the hall cards' full width.
    var fillsWidth = false

    var body: some View {
        Group {
            if fillsWidth {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        pill(item)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            pill(item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func pill(_ item: Item) -> some View {
        let isSelected = selection == item
        let button = Button {
            withAnimation(ZotMotion.select) {
                selection = (isSelected && allowsDeselect) ? nil : item
            }
            Haptics.selection()
        } label: {
            Text(title(item))
                .font(ZotFont.pill.weight(isSelected ? .semibold : .medium))
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, fillsWidth ? 8 : 14)
                .padding(.vertical, fillsWidth ? 8 : 9)
                .background(
                    isSelected ? Color.selectWash : Color.card,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.uciBlue : Color.ink)
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.uciBlue.opacity(0.28) : Color.cardBorder,
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(item))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])

        if let hint = PillSelectionAccessibility.hint(
            title: title(item),
            isSelected: isSelected,
            allowsDeselect: allowsDeselect
        ) {
            button.accessibilityHint(hint)
        } else {
            button
        }
    }
}

// MARK: - "Typical" estimate tag

/// Tiny label marking a busyness reading as a typical-pattern estimate, not live data.
struct TypicalTag: View {
    var body: some View {
        Text("TYPICAL")
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .foregroundStyle(.secondary)
            .accessibilityLabel("Typical estimate, not live data")
    }
}

// MARK: - Day rush strip (24 hourly bars)

/// Compact hour-by-hour rush chart: one thin bar per hour, current hour highlighted.
struct RushStrip: View {
    /// 24 hourly percents (0 = closed).
    let curve: [Int]
    let currentHour: Int
    var barMaxHeight: CGFloat = 34

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let value = hour < curve.count ? curve[hour] : 0
                    let isNow = hour == currentHour
                    Capsule()
                        .fill(
                            isNow
                                ? AnyShapeStyle(Color.uciBlue)
                                : value == 0
                                    ? AnyShapeStyle(Color.primary.opacity(0.06))
                                    : AnyShapeStyle(Color.uciBlue.opacity(0.28))
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, barMaxHeight * CGFloat(value) / 100))
                }
            }
            .frame(height: barMaxHeight, alignment: .bottom)

            // Approximate tick labels: 6 AM sits a quarter in, 12 PM centered, 6 PM three-quarters.
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Text("6 AM").position(x: geo.size.width * 6.5 / 24, y: 6)
                    Text("12 PM").position(x: geo.size.width * 12.5 / 24, y: 6)
                    Text("6 PM").position(x: geo.size.width * 18.5 / 24, y: 6)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            }
            .frame(height: 12)
        }
        // GymRushCard owns VoiceOver (typical + peak + now + summaries).
        .accessibilityHidden(true)
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
        RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(height: height)
            .opacity(pulse ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle = "Try Again"
    var retry: (() -> Void)?
    /// Optional second CTA (e.g. Campus Open Now: View next place + Show closed).
    var secondaryActionTitle: String? = nil
    var secondaryRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 64, height: 64)
                .background(Color.uciGold.opacity(0.14), in: Circle())
            Text(title)
                .font(ZotFont.cardTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(ZotFont.caption)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if retry != nil || secondaryRetry != nil {
                VStack(spacing: 8) {
                    if let retry {
                        Button(actionTitle, action: retry)
                            .buttonStyle(.bordered)
                            .tint(.uciBlue)
                    }
                    if let secondaryRetry, let secondaryActionTitle {
                        Button(secondaryActionTitle, action: secondaryRetry)
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .padding(.horizontal, 28)
    }
}

// MARK: - Screen header

struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    /// When set, shows a quiet top-right gear that opens Settings.
    var onSettings: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(ZotFont.hero())
                    .foregroundStyle(Color.ink)
                    .tracking(-0.4)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let onSettings {
                Button {
                    onSettings()
                    Haptics.selection()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 36)
                        .glassIconCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }
}

// MARK: - Liquid Glass adoption (iOS 26+)

// The app builds against the iOS 26 SDK, so standard chrome (tab bar, sheets,
// pills) renders with Liquid Glass automatically on iOS 26 devices. These
// helpers adopt the newer behaviors explicitly while degrading cleanly on
// iOS 17–18.

extension View {
    /// Liquid Glass tab bar behavior: the bar condenses into a floating glass
    /// pill while scrolling down and re-expands on scroll up.
    @ViewBuilder
    func liquidGlassTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Circular icon-button chrome: interactive Liquid Glass on iOS 26,
    /// hairline-bordered card circle earlier.
    @ViewBuilder
    func glassIconCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self
                .background(Color.card, in: Circle())
                .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Status bar backdrop

/// Paints the page background under the status bar / Dynamic Island, and keeps
/// scrolled list content from showing through the transparent system chrome.
struct StatusBarBackdrop: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.screen.ignoresSafeArea())
            .overlay(alignment: .top) {
                // Zero-height anchor that expands into the top safe area and
                // sits above ScrollView content as it moves under the status bar.
                Color.screen
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)
                    .background(Color.screen)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func statusBarBackdrop() -> some View {
        modifier(StatusBarBackdrop())
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
            Text(UpdatedAgoCopy.phrase(from: date, now: context.date))
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
