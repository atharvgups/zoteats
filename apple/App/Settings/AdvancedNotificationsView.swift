import SwiftUI
import ZotEatsKit

/// Per-type alert switches, tucked behind Settings → Notifications → Advanced.
struct AdvancedNotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var diningOpenEnabled = OpeningAlerts.diningOpenEnabled
    @State private var diningClosingEnabled = OpeningAlerts.diningClosingEnabled
    @State private var campusHoursEnabled = OpeningAlerts.campusHoursEnabled
    @State private var libraryBusyEnabled = LibraryBusyAlerts.isEnabled
    @State private var autoMealActivity = MealActivityManager.autoStartEnabled
    @State private var alertsDenied = false
    @State private var watchedPlaces = OpeningAlerts.watchedIDs
    @State private var showOpeningAlerts = false
    @State private var testPingSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(
                    title: "Advanced",
                    subtitle: "Pick which pings fire when Notifications is on"
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text("Alerts")
                        .font(ZotFont.sectionTitle)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.bottom, 8)

                    alertToggle(
                        isOn: $diningOpenEnabled,
                        title: "Halls opening",
                        caption: "Ping when a watched hall’s meal starts.",
                        identifier: "dining-open-alerts-toggle"
                    ) { enabled in
                        OpeningAlerts.diningOpenEnabled = enabled
                        OpeningAlerts.markAdvancedCustomized()
                        await OpeningAlerts.refreshSchedules()
                        if enabled {
                            await FavoriteAlerts.scheduleNextRefresh()
                        }
                    }

                    ZotHairline(leading: 0)

                    alertToggle(
                        isOn: $diningClosingEnabled,
                        title: "Halls closing soon",
                        caption: "Twenty minutes before that meal ends.",
                        identifier: "dining-closing-alerts-toggle"
                    ) { enabled in
                        OpeningAlerts.diningClosingEnabled = enabled
                        OpeningAlerts.markAdvancedCustomized()
                        await OpeningAlerts.refreshSchedules()
                    }

                    ZotHairline(leading: 0)

                    Button {
                        showOpeningAlerts = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Halls to watch")
                                    .font(ZotFont.body)
                                    .foregroundStyle(.primary)
                                Text("Anteatery is the default if you pick none.")
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
                        .comfortableRowHit()
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("opening-alerts-row")

                    ZotHairline(leading: 0)

                    alertToggle(
                        isOn: $campusHoursEnabled,
                        title: "Campus favorites",
                        caption: "Open and closing pings for hearted cafés with posted hours.",
                        identifier: "campus-hours-alerts-toggle"
                    ) { enabled in
                        OpeningAlerts.campusHoursEnabled = enabled
                        OpeningAlerts.markAdvancedCustomized()
                        await OpeningAlerts.refreshSchedules()
                    }

                    ZotHairline(leading: 0)

                    alertToggle(
                        isOn: $libraryBusyEnabled,
                        title: "Library getting busy",
                        caption: "When Waitz shows a library at \(LibraryBusyAlertMath.percentThreshold)% or busier. Real occupancy only.",
                        identifier: "library-busy-alerts-toggle"
                    ) { enabled in
                        LibraryBusyAlerts.isEnabled = enabled
                        OpeningAlerts.markAdvancedCustomized()
                        if enabled {
                            await LibraryBusyAlerts.runCheck()
                        }
                    }

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
                    .toggleStyle(.switch)
                    .tint(Color.accent)
                    .accessibilityIdentifier("auto-meal-activity-toggle")
                    .onChange(of: autoMealActivity) { _, enabled in
                        MealActivityManager.autoStartEnabled = enabled
                        OpeningAlerts.markAdvancedCustomized()
                        Haptics.selection()
                    }
                    .comfortableRowHit()
                    .padding(.vertical, 6)

                    if !MealActivityManager.systemActivitiesEnabled {
                        ZotHairline(leading: 0)
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Text("Live Activities are off — open iOS Settings for Anteats")
                                .font(ZotFont.caption)
                                .foregroundStyle(TagPalette.terracotta)
                                .comfortableRowHit()
                                .padding(.vertical, 6)
                        }
                        .accessibilityIdentifier("live-activities-off-link")
                    }

                    if diningOpenEnabled || diningClosingEnabled || campusHoursEnabled || libraryBusyEnabled {
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
                                .comfortableRowHit()
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("test-notification-button")
                    }

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
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .zotCard()
                .padding(.horizontal, 20)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .appCanvas()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.leading, 8)
            .accessibilityLabel("Back")
        }
        .sheet(isPresented: $showOpeningAlerts) {
            OpeningAlertsPicker(watched: $watchedPlaces)
        }
        .onAppear {
            diningOpenEnabled = OpeningAlerts.diningOpenEnabled
            diningClosingEnabled = OpeningAlerts.diningClosingEnabled
            campusHoursEnabled = OpeningAlerts.campusHoursEnabled
            libraryBusyEnabled = LibraryBusyAlerts.isEnabled
            autoMealActivity = MealActivityManager.autoStartEnabled
            watchedPlaces = OpeningAlerts.watchedIDs
        }
    }

    private func alertToggle(
        isOn: Binding<Bool>,
        title: String,
        caption: String,
        identifier: String,
        onEnable: @escaping (Bool) async -> Void
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZotFont.body)
                Text(caption)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(Color.accent)
        .accessibilityIdentifier(identifier)
        .onChange(of: isOn.wrappedValue) { _, enabled in
            guard enabled else {
                Task { await onEnable(false) }
                return
            }
            Task {
                let granted = await FavoriteAlerts.requestPermission()
                if granted {
                    alertsDenied = false
                    await onEnable(true)
                    await FavoriteAlerts.scheduleNextRefresh()
                } else {
                    isOn.wrappedValue = false
                    alertsDenied = true
                }
            }
        }
        .comfortableRowHit()
        .padding(.vertical, 6)
    }
}
