import SwiftUI

// Settings — appearance control plus honest app/data-source info.

struct SettingsView: View {
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

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
        }
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

            Text("All data comes from public, community sources and may change without notice.")
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
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
                    .foregroundStyle(isSelected ? .white : Color.uciBlue)
                Text(option.label)
                    .font(ZotFont.pill)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? AnyShapeStyle(Color.uciBlue) : AnyShapeStyle(Color.screen),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1)
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
