import SwiftUI
import ZotEatsKit

// Settings — quiet cards for appearance, alerts, this iPhone, and honest sources.

struct SettingsView: View {
    let prefs: Preferences
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
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Settings", subtitle: "Alerts, sources, and this iPhone")

                    VStack(alignment: .leading, spacing: 16) {
                        appearanceCard
                        alertsCard
                        thisIPhoneCard
                        sourcesCard
                        aboutCard
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
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
                .tracking(0.6)
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

    // MARK: - Alerts (+ Live Activity)

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Alerts")
                .font(ZotFont.sectionTitle)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
                .padding(.bottom, 8)

            Toggle(isOn: $alertsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorite dishes")
                        .font(ZotFont.body)
                    Text("Ping when a hearted dish is on today’s hall menu.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.ink)
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
            .padding(.vertical, 10)

            ZotHairline(leading: 0)

            Toggle(isOn: $menuDropEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu drop")
                        .font(ZotFont.body)
                    Text("Ping when a future hall day posts.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.ink)
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
            .padding(.vertical, 10)

            ZotHairline(leading: 0)

            Button {
                showOpeningAlerts = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Opening")
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
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.ink.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("opening-alerts-row")
            .padding(.vertical, 10)

            ZotHairline(leading: 0)

            Toggle(isOn: $autoMealActivity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meal countdown")
                        .font(ZotFont.body)
                    Text("Island / Lock Screen in the last \(MealActivityManager.autoStartWindowMinutes) minutes of a meal.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.ink)
            .accessibilityIdentifier("auto-meal-activity-toggle")
            .onChange(of: autoMealActivity) { _, enabled in
                MealActivityManager.autoStartEnabled = enabled
                Haptics.selection()
            }
            .padding(.vertical, 10)

            if !MealActivityManager.systemActivitiesEnabled {
                ZotHairline(leading: 0)
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Live Activities are off — open iOS Settings for Anteats")
                        .font(ZotFont.caption)
                        .foregroundStyle(TagPalette.terracotta)
                }
                .padding(.vertical, 10)
                .accessibilityIdentifier("live-activities-off-link")
            }

            // Dogfood verify only when an alert path is actually on — keep
            // Alerts from feeling like a permanent QA panel.
            if alertsEnabled || menuDropEnabled || !watchedPlaces.isEmpty {
                ZotHairline(leading: 0)
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
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .accessibilityIdentifier("test-notification-button")
            }

            if alertsDenied {
                ZotHairline(leading: 0)
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Text("Notifications are off — open iOS Settings for Anteats")
                        .font(ZotFont.caption)
                        .foregroundStyle(TagPalette.terracotta)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - This iPhone (ratings + plate honesty)

    private var thisIPhoneCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This iPhone")
                .font(ZotFont.sectionTitle)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
                .padding(.bottom, 8)

            if prefs.mealReviews.isEmpty {
                Text("Star a dish on Eat. Ratings stay on this iPhone.")
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(MealReviewLogic.sortedForDisplay(prefs.mealReviews).enumerated()), id: \.element.id) { index, review in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(review.dishName)
                                .font(ZotFont.body.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            StarRatingControl(stars: review.stars, size: 12, interactive: false)
                            if !review.note.isEmpty {
                                Text(review.note)
                                    .font(ZotFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Button {
                            prefs.clearReview(dishName: review.dishName)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove rating for \(review.dishName)")
                    }
                    .padding(.vertical, 8)
                    if index < prefs.mealReviews.count - 1 {
                        ZotHairline(leading: 0)
                    }
                }
            }

            ZotHairline(leading: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nutrition and Plate")
                    .font(ZotFont.body)
                Text("Macros come from Anteater API when a dish posts them. Plate is local and resets each Irvine day.")
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sources")
                .font(ZotFont.sectionTitle)
                .tracking(0.6)
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
            .padding(.vertical, 10)
        }
        .accessibilityLabel("\(title). Opens in browser.")
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("About")
                .font(ZotFont.sectionTitle)
                .tracking(0.6)
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
            .padding(.vertical, 10)
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

            ZotHairline(leading: 0)

            Text("Home Screen → Add Anteats. Open Eat once so glances paint from today’s snapshot.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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
    SettingsView(prefs: Preferences())
}
