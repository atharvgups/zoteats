import SwiftUI
import ZotEatsKit

// Settings — quiet cards for appearance, notifications, and honest sources.

struct SettingsView: View {
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

    @Environment(\.dismiss) private var dismiss

    // Easter egg: triple-tap the version row for a proper UCI cheer.
    @State private var versionTaps = 0
    @State private var showZot = false
    @State private var showFeedbackForm = false

    @State private var notificationsEnabled = OpeningAlerts.masterEnabled
    @State private var alertsDenied = false

    private var appearance: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Settings", subtitle: "Appearance, alerts, and sources")

                    VStack(alignment: .leading, spacing: 16) {
                        appearanceCard
                        feedbackCard
                        notificationsCard
                        sourcesCard
                        aboutCard
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .appCanvas()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary, .quaternary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .accessibilityLabel("Close settings")
            }
            .overlay {
                if showZot {
                    ZotCheer()
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showFeedbackForm) {
                SafariView(url: FeedbackForm.url)
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .tint(Color.accent)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(ZotFont.sectionTitle)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)

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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - Feedback

    /// Own card near the top so it is not buried under Alerts / About.
    /// Full-row hit target — plain buttons otherwise miss Spacer / padding.
    private var feedbackCard: some View {
        Button {
            showFeedbackForm = true
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feedback")
                        .font(ZotFont.body)
                        .foregroundStyle(.primary)
                    Text("Share ideas or report a problem")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .comfortableRowHit()
            .padding(14)
        }
        .buttonStyle(.plain)
        .zotCard()
        .accessibilityLabel("Feedback. Opens the Anteats feedback form.")
        .accessibilityHint("Opens in a browser view")
        .accessibilityIdentifier("settings-feedback-row")
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications")
                .font(ZotFont.sectionTitle)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
                .padding(.bottom, 8)

            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(ZotFont.body)
                    Text("Pings for halls, campus, and study.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(Color.accent)
            .accessibilityIdentifier("notifications-master-toggle")
            .onChange(of: notificationsEnabled) { _, enabled in
                Task { await setMasterEnabled(enabled) }
            }
            .comfortableRowHit()
            .padding(.vertical, 6)

            if alertsDenied {
                ZotHairline(leading: 0)
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Notifications are off — open iOS Settings for Anteats")
                        .font(ZotFont.caption)
                        .foregroundStyle(TagPalette.terracotta)
                        .comfortableRowHit()
                        .padding(.vertical, 6)
                }
            }

            ZotHairline(leading: 0)

            NavigationLink {
                AdvancedNotificationsView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Advanced")
                            .font(ZotFont.body)
                            .foregroundStyle(.secondary)
                        Text("Halls, campus, library, meal countdown.")
                            .font(ZotFont.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .comfortableRowHit()
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("advanced-notifications-row")
            .accessibilityLabel("Advanced notifications")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private func setMasterEnabled(_ enabled: Bool) async {
        guard enabled else {
            OpeningAlerts.masterEnabled = false
            await OpeningAlerts.refreshSchedules()
            Haptics.selection()
            return
        }
        let granted = await FavoriteAlerts.requestPermission()
        if granted {
            alertsDenied = false
            let applyDefaults = NotificationMasterLogic.shouldApplySensibleDefaults(
                masterJustEnabled: true,
                advancedCustomized: OpeningAlerts.advancedCustomized,
                anyChildEnabled: OpeningAlerts.anyChildEnabled
            )
            OpeningAlerts.masterEnabled = true
            if applyDefaults {
                OpeningAlerts.applySensibleDefaults()
            }
            await OpeningAlerts.refreshSchedules()
            if LibraryBusyAlerts.isEnabled {
                await LibraryBusyAlerts.runCheck()
            }
            Haptics.selection()
        } else {
            notificationsEnabled = false
            alertsDenied = true
        }
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sources")
                .font(ZotFont.sectionTitle)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
                .padding(.bottom, 8)

            sourceRow(
                icon: "fork.knife",
                title: "Anteater API",
                subtitle: "Live hall menus, plus nutrition when a dish posts it.",
                url: "https://anteaterapi.com"
            )
            ZotHairline(leading: 0)
            sourceRow(
                icon: "cup.and.saucer.fill",
                title: "Dining Hub",
                subtitle: "Retail hours. Live café board only when Hub publishes; typical packs stay labeled, never as today. Oasis is still Coming Soon.",
                url: "https://uci.campusdish.com"
            )
            ZotHairline(leading: 0)
            sourceRow(
                icon: "chart.bar.fill",
                title: "Waitz",
                subtitle: "Live occupancy for Langson and Science — not Student Center.",
                url: "https://waitz.io/irvine"
            )
            ZotHairline(leading: 0)
            sourceRow(
                icon: "books.vertical.fill",
                title: "LibCal",
                subtitle: "Official Langson and Science building hours.",
                url: "https://www.lib.uci.edu/hours"
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private func sourceRow(icon: String, title: String, subtitle: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 26)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(ZotFont.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .comfortableRowHit()
            .padding(.vertical, 6)
        }
        .accessibilityLabel("\(title). Opens in browser.")
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About")
                .font(ZotFont.sectionTitle)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
                .padding(.bottom, 8)

            Text("Unofficial student project for UC Irvine. Not affiliated with the university.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

            ZotHairline(leading: 0)

            HStack {
                Text("Version")
                    .font(ZotFont.body)
                Spacer()
                Text(Self.versionString)
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
            }
            .comfortableRowHit()
            .padding(.vertical, 6)
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
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
                .font(ZotFont.face(20, relativeTo: .title3).weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: [.uciBlue, .uciBlueDeep], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
        )
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
                    .foregroundStyle(isSelected ? Color.ink : Color.secondary)
                Text(option.label)
                    .font(ZotFont.pill.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.ink : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.selectWash : Color.clear,
                in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.ink.opacity(0.28) : Color.cardBorder,
                        lineWidth: 1
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
