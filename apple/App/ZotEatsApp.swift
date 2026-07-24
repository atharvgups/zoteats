import SwiftUI

/// User-selectable appearance: follow the system (auto dark at night), or force light/dark.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "zoteats.appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// UIKit window override; .unspecified follows the device setting.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// The persisted setting.
    static var saved: AppearanceSetting {
        AppearanceSetting(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// Applies this appearance to every window, imperatively via UIKit.
    /// Deliberately avoids `preferredColorScheme`, which hung the render loop
    /// (blank UI) on the CI simulator when driven from a root-view @AppStorage.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.overrideUserInterfaceStyle != interfaceStyle {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}

@main
struct ZotEatsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.uciBlue)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await FavoriteAlerts.runCheck()
                    await OpeningAlerts.refreshSchedules()
                }
            case .background:
                FavoriteAlerts.scheduleNextRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(FavoriteAlerts.refreshTaskID)) {
            await FavoriteAlerts.runCheck()
            await OpeningAlerts.refreshSchedules()
            await FavoriteAlerts.scheduleNextRefresh()
        }
    }
}

enum AppTab: String, Hashable {
    case dining, campus, gym, busyness
}

/// Environment action child screens use to open the Settings sheet from their headers.
private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}

extension EnvironmentValues {
    var openSettings: (@MainActor @Sendable () -> Void)? {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

struct RootTabView: View {
    @State private var selection: AppTab = RootTabView.initialTab()
    // -showSettings lets CI screenshot the Settings sheet directly.
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("-showSettings")

    // App-lifetime stores: the iOS 26 tab system unloads off-screen tabs, so
    // per-view stores were recreated (and refetched everything) on every tab
    // switch. Owning them here makes switching instant after the first load.
    @State private var diningStore = DiningStore()
    @State private var campusStore = CampusStore()
    @State private var gymStore = GymStore()
    @State private var busynessStore = BusynessStore()
    @State private var preferences = Preferences()

    var body: some View {
        tabs
            .liquidGlassTabBar()
            .environment(\.openSettings) { showSettings = true }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                // Restore the persisted appearance once the window hierarchy exists.
                AppearanceSetting.saved.apply()
            }
    }

    // Visible labels are Eat / Campus / Gym / Study; internal AppTab ids and
    // the -initialTab launch args keep their historical names for CI stability.
    // Modern Tab syntax (iOS 18+) is required for Liquid Glass tab bar
    // behaviors like minimize-on-scroll.
    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Eat", systemImage: "fork.knife", value: AppTab.dining) {
                DiningView(store: diningStore, prefs: preferences)
            }
            Tab("Campus", systemImage: "cup.and.saucer.fill", value: AppTab.campus) {
                CampusView(store: campusStore, prefs: preferences)
            }
            Tab("Gym", systemImage: "dumbbell.fill", value: AppTab.gym) {
                GymView(store: gymStore)
            }
            Tab("Study", systemImage: "books.vertical.fill", value: AppTab.busyness) {
                BusynessView(store: busynessStore)
            }
        }
    }

    /// CI drives per-tab screenshots by launching with `-initialTab <tab>`.
    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-initialTab"), index + 1 < args.count,
           let tab = AppTab(rawValue: args[index + 1]) {
            return tab
        }
        return .dining
    }
}

#Preview {
    RootTabView()
        .tint(.uciBlue)
}
