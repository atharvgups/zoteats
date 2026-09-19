import SwiftUI
import ZotEatsKit

// One level under Settings → Notifications. Every existing alert category
// lives here so the main surface stays short. No new features.

struct AdvancedNotificationSettings: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var diningOpenEnabled: Bool
    @Binding var diningClosingEnabled: Bool
    @Binding var campusHoursEnabled: Bool
    @Binding var libraryBusyEnabled: Bool
    @Binding var alertsDenied: Bool

    @State private var watchedPlaces = OpeningAlerts.watchedIDs
    @State private var showOpeningAlerts = false
    @State private var testPingSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Advanced notification settings")

                VStack(alignment: .leading, spacing: 0) {
                    alertToggle(
                        isOn: $diningOpenEnabled,
                        title: "Halls opening",
                        caption: "Ping when a watched hall’s meal starts.",
                        identifier: "dining-open-alerts-toggle"
                    ) { enabled in
                        OpeningAlerts.diningOpenEnabled = enabled
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
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("opening-alerts-row")
                    .padding(.vertical, 10)

                    ZotHairline(leading: 0)

                    alertToggle(
                        isOn: $campusHoursEnabled,
                        title: "Campus favorites",
                        caption: "Open and closing pings for hearted cafés with posted hours.",
                        identifier: "campus-hours-alerts-toggle"
                    ) { enabled in
                        OpeningAlerts.campusHoursEnabled = enabled
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
                        if enabled {
                            await LibraryBusyAlerts.runCheck()
                        }
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
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .accessibilityIdentifier("test-notification-button")
                    }

                    if alertsDenied {
                        ZotHairline(leading: 0)
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Text("Notifications are off. Open iOS Settings for Anteats")
                                .font(ZotFont.caption)
                                .foregroundStyle(TagPalette.terracotta)
                        }
                        .padding(.vertical, 10)
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
            .accessibilityLabel("Back to settings")
            .accessibilityIdentifier("back-to-settings")
        }
        .sheet(isPresented: $showOpeningAlerts) {
            OpeningAlertsPicker(watched: $watchedPlaces)
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
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        AdvancedNotificationSettings(
            diningOpenEnabled: .constant(true),
            diningClosingEnabled: .constant(true),
            campusHoursEnabled: .constant(true),
            libraryBusyEnabled: .constant(true),
            alertsDenied: .constant(false)
        )
    }
}
