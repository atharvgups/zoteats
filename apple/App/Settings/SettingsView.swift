import SwiftUI

// Settings — appearance control plus honest app/data-source info.

struct SettingsView: View {
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

    @Environment(\.dismiss) private var dismiss

    // Easter egg: triple-tap the version row for a proper UCI cheer.
    @State private var versionTaps = 0
    @State private var showZot = false

    @State private var alertsEnabled = FavoriteAlerts.isEnabled
    @State private var menuDropEnabled = MenuDropAlerts.isEnabled
    @State private var autoMealActivity = MealActivityManager.autoStartEnabled
    @State private var alertsDenied = false
    @State private var watchedPlaces = OpeningAlerts.watchedIDs
    @State private var showOpeningAlerts = false
    @State private var testPingSent = false

    private var appearance: AppearanceSetting {
        AppearanceSetting(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(title: "Settings", subtitle: "Make Anteats yours")

                    VStack(alignment: .leading, spacing: 12) {
                        appearanceCard
                        alertsCard
                        widgetsCard
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
            .sheet(isPresented: $showOpeningAlerts) {
                OpeningAlertsPicker(watched: $watchedPlaces)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - Notifications (+ Live Activity)

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(ZotFont.sectionTitle)

            Toggle(isOn: $alertsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorite dish alerts")
                        .font(ZotFont.body)
                    Text("Ping when a hearted dish is on today's menu.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.uciBlue)
            .accessibilityIdentifier("favorite-alerts-toggle")
            .onChange(of: alertsEnabled) { _, enabled in
                guard enabled else {
                    FavoriteAlerts.isEnabled = false
                    return
                }
                Task {
                    let granted = await FavoriteAlerts.requestPermission()
                    FavoriteAlerts.isEnabled = granted
                    if granted {
                        await FavoriteAlerts.runCheck()
                        await OpeningAlerts.refreshSchedules()
                        await FavoriteAlerts.scheduleNextRefresh()
                        WidgetReloader.reloadAll()
                    } else {
                        alertsEnabled = false
                        alertsDenied = true
                    }
                }
            }

            Toggle(isOn: $menuDropEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu-drop alerts")
                        .font(ZotFont.body)
                    Text("Ping when a future day's menu posts.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.uciBlue)
            .accessibilityIdentifier("menu-drop-alerts-toggle")
            .onChange(of: menuDropEnabled) { _, enabled in
                guard enabled else {
                    MenuDropAlerts.isEnabled = false
                    return
                }
                Task {
                    let granted = await FavoriteAlerts.requestPermission()
                    MenuDropAlerts.isEnabled = granted
                    if granted {
                        await MenuDropAlerts.runCheck()
                        await FavoriteAlerts.scheduleNextRefresh()
                        WidgetReloader.reloadAll()
                    } else {
                        menuDropEnabled = false
                        alertsDenied = true
                    }
                }
            }

            Button {
                showOpeningAlerts = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Opening alerts")
                            .font(ZotFont.body)
                            .foregroundStyle(.primary)
                        Text("Watch a hall or café — ping when it opens.")
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !watchedPlaces.isEmpty {
                        Text("\(watchedPlaces.count)")
                            .font(ZotFont.pill.weight(.semibold))
                            .foregroundStyle(Color.uciBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.uciBlue.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("opening-alerts-row")

            Toggle(isOn: $autoMealActivity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto meal countdown")
                        .font(ZotFont.body)
                    Text("Start Island / Lock Screen timer in the last \(MealActivityManager.autoStartWindowMinutes) minutes of a meal.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.uciBlue)
            .accessibilityIdentifier("auto-meal-activity-toggle")
            .onChange(of: autoMealActivity) { _, enabled in
                MealActivityManager.autoStartEnabled = enabled
                Haptics.selection()
            }

            if !MealActivityManager.systemActivitiesEnabled {
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Live Activities are off — open iOS Settings for Anteats")
                        .font(ZotFont.caption)
                        .foregroundStyle(TagPalette.terracotta)
                }
                .accessibilityIdentifier("live-activities-off-link")
            }

            // Dogfood verify only when an alert path is actually on — keep
            // Notifications from feeling like a permanent QA panel.
            if alertsEnabled || menuDropEnabled || !watchedPlaces.isEmpty {
                Button {
                    Task {
                        let granted = await FavoriteAlerts.requestPermission()
                        if granted {
                            alertsDenied = false
                            await FavoriteAlerts.sendTestNotification()
                            withAnimation { testPingSent = true }
                        } else {
                            alertsDenied = true
                        }
                    }
                } label: {
                    Text(testPingSent ? "Test ping sent" : "Send test notification")
                        .font(ZotFont.caption.weight(.semibold))
                        .foregroundStyle(Color.uciBlue)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .accessibilityIdentifier("test-notification-button")
            }

            if alertsDenied {
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Notifications are off — open iOS Settings for Anteats")
                        .font(ZotFont.caption)
                        .foregroundStyle(TagPalette.terracotta)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - Widgets

    private var widgetsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Widgets")
                .font(ZotFont.sectionTitle)

            Text("Home Screen → Edit → Add Widget → Anteats.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                widgetTip(icon: "building.2.fill", title: "Dining Halls", detail: "Open halls + closes-in countdown")
                widgetTip(icon: "fork.knife", title: "Today's Menu", detail: "Meal glance + Eat Filters hint")
                widgetTip(icon: "heart.fill", title: "Favorites Today", detail: "Hearted dishes on today’s board")
                widgetTip(icon: "cup.and.saucer.fill", title: "Campus Open Now", detail: "Cafés and markets open now")
                widgetTip(icon: "books.vertical.fill", title: "Quietest Library", detail: "Lock Screen / StandBy glance")
            }

            Text("Tip: open Eat once after install so Today’s Menu / Favorites can read today’s board from the app, then long-press a blank widget → Edit Widget / Remove and re-add if it still looks redacted.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private func widgetTip(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.uciBlue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ZotFont.body.weight(.medium))
                Text(detail)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(ZotFont.sectionTitle)

            Text("Anteats is an unofficial student project for UC Irvine — dining menus, campus food hours, and live library busyness in one place. Not affiliated with UC Irvine.")
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
        .padding(14)
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
                subtitle: "Community-maintained UCI hall menus",
                url: "https://anteaterapi.com"
            )
            Divider()
            sourceRow(
                icon: "cup.and.saucer.fill",
                title: "Campus food — UCI Dining Hub",
                subtitle: "Retail hours and menus (Starbucks, cafés, markets)",
                url: "https://uci.campusdish.com"
            )
            Divider()
            sourceRow(
                icon: "chart.bar.fill",
                title: "Busyness — Waitz",
                subtitle: "Live library occupancy sensors",
                url: "https://waitz.io/irvine"
            )
            Divider()
            sourceRow(
                icon: "books.vertical.fill",
                title: "Library hours — UCI LibCal",
                subtitle: "Official Langson + Science building hours",
                url: "https://www.lib.uci.edu/hours"
            )

            Text("All data comes from public, community sources and may change without notice. Library busyness is live sensor data.")
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
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
