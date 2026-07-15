import SwiftUI

// Settings — appearance control plus honest app/data-source info.

struct SettingsView: View {
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

    @Environment(\.dismiss) private var dismiss

    // Easter egg: triple-tap the version row for a proper UCI cheer.
    @State private var versionTaps = 0
    @State private var showZot = false

    private var appearance: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Settings", subtitle: "Make ZotEats yours")

                    VStack(alignment: .leading, spacing: 16) {
                        appearanceCard
                        aboutCard
                        dataSourcesCard
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.screen)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary, .quaternary)
                }
                .buttonStyle(.plain)
                .padding(16)
                .accessibilityLabel("Close settings")
            }
            .overlay {
                if showZot {
                    ZotCheer()
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(ZotFont.sectionTitle)

            HStack(spacing: 10) {
                ForEach(AppearanceSetting.allCases) { option in
                    AppearanceOption(
                        option: option,
                        isSelected: appearance == option
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            appearanceRaw = option.rawValue
                        }
                        option.apply()
                        Haptics.selection()
                    }
                }
            }

            Text("System follows your iPhone — light by day, dark at night.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(ZotFont.sectionTitle)

            Text("ZotEats is an unofficial student project for UC Irvine — dining menus, gym hours, and live campus busyness in one place. Not affiliated with UC Irvine.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Version")
                    .font(ZotFont.body)
                Spacer()
                Text(Self.versionString)
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                versionTaps += 1
                guard versionTaps >= 3 else { return }
                versionTaps = 0
                Haptics.soft()
                withAnimation(.spring(duration: 0.4)) {
                    showZot = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showZot = false
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - Data sources

    private var dataSourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data Sources")
                .font(ZotFont.sectionTitle)

            sourceRow(
                icon: "fork.knife",
                title: "Dining — Anteater API",
                subtitle: "Community-maintained UCI data API",
                url: "https://anteaterapi.com"
            )
            Divider()
            sourceRow(
                icon: "chart.bar.fill",
                title: "Busyness — Waitz",
                subtitle: "UCI's public live-occupancy feed",
                url: "https://waitz.io/irvine"
            )
            Divider()
            sourceRow(
                icon: "dumbbell.fill",
                title: "ARC hours — UCI Campus Rec",
                subtitle: "Verify seasonal changes on the official page",
                url: "https://www.campusrec.uci.edu/arc/hours.html"
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TypicalTag()
                    Text("ARC busyness is a typical-pattern estimate based on usual gym rushes — not a live measurement — and may not match actual crowds. Library busyness is live sensor data.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Text("All data comes from public, community sources and may change without notice.")
                    .font(ZotFont.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private func sourceRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.uciBlue)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(ZotFont.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityLabel("\(title). Opens in browser.")
    }

    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Hidden Zot cheer

/// Three ants marching in with the anteater battle cry. Rewards curious tappers.
private struct ZotCheer: View {
    @State private var march = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "ant.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.uciGold)
                        .offset(y: march ? -6 : 2)
                        .animation(
                            .easeInOut(duration: 0.35)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.12),
                            value: march
                        )
                }
            }
            Text("Zot! Zot! Zot!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: [.uciBlue, .uciBlueDeep], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: Color.uciBlue.opacity(0.35), radius: 16, y: 6)
        .onAppear { march = true }
        .accessibilityLabel("Zot zot zot!")
    }
}

// MARK: - Appearance option tile

private struct AppearanceOption: View {
    let option: AppearanceSetting
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 7) {
                Image(systemName: option.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.uciBlue : Color.secondary)
                Text(option.label)
                    .font(ZotFont.pill.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.uciBlue : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.uciBlue.opacity(0.1) : Color.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.uciBlue.opacity(0.4) : Color.cardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label) appearance")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    SettingsView()
}
