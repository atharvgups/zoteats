import SwiftUI
import ZotEatsKit

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

    init() {
        NotificationRouter.shared.install()
    }

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
                    await MenuDropAlerts.runCheck()
                    await OpeningAlerts.refreshSchedules()
                    await MealActivityAutoStartRunner.run()
                    WidgetReloader.reloadAll()
                }
            case .background:
                Task { await FavoriteAlerts.scheduleNextRefresh() }
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(FavoriteAlerts.refreshTaskID)) {
            await FavoriteAlerts.runCheck()
            await MenuDropAlerts.runCheck()
            await OpeningAlerts.refreshSchedules()
            await MealActivityAutoStartRunner.run()
            WidgetReloader.reloadAll()
            await FavoriteAlerts.scheduleNextRefresh()
        }
    }
}

enum AppTab: String, Hashable {
    /// `gym` kept for deep-link / CI arg compatibility — not a shipping tab.
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = RootTabView.initialTab()
    // -showSettings lets CI screenshot the Settings sheet directly.
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("-showSettings")
    @State private var pendingDeepLink: AnteatsDeepLink?

    // App-lifetime stores: the iOS 26 tab system unloads off-screen tabs, so
    // per-view stores were recreated (and refetched everything) on every tab
    // switch. Owning them here makes switching instant after the first load.
    @State private var diningStore = DiningStore()
    @State private var campusStore = CampusStore()
    @State private var busynessStore = BusynessStore()
    @State private var preferences = Preferences()
    @State private var plate = PlateStore()
    /// Bumps after each meal wrap-up tick so Auto meal countdown fires off Eat.
    @State private var wrapUpEpoch = 0

    private var wrapUpWatchID: String {
        "\(wrapUpEpoch)|\(diningStore.dayEpoch)|\(diningStore.locations.value?.map(\.id).joined() ?? "")"
    }

    var body: some View {
        let _ = wrapUpEpoch
        tabs
            .liquidGlassTabBar()
            .environment(\.openSettings) { showSettings = true }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task(id: wrapUpWatchID) {
                await watchMealWrapUps()
            }
            .onAppear {
                // Restore the persisted appearance once the window hierarchy exists.
                AppearanceSetting.saved.apply()
                plate.ensureCurrentDay()
                preferences.reloadMenuFiltersFromSharedDefaults()
                NotificationRouter.shared.onDeepLink = { link in
                    applyDeepLink(link)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    plate.ensureCurrentDay()
                    preferences.reloadMenuFiltersFromSharedDefaults()
                    // Recompute Campus open/close from cached schedules (not a full network wait).
                    Task { await campusStore.loadPlaces() }
                    // Study is an app-lifetime store — refresh Waitz on warm resume.
                    Task { await busynessStore.load() }
                    // Purge live "today" menus after Irvine midnight, then always
                    // recompute hall open state from cached meal windows (Campus parity).
                    diningStore.ensureCurrentDay()
                    Task {
                        await diningStore.loadLocations()
                        wrapUpEpoch += 1
                    }
                }
            }
            .onOpenURL { url in
                if let link = AnteatsDeepLink.parse(url) {
                    applyDeepLink(link)
                }
            }
    }

    /// Sleep until the next hall meal wrap-up (T−45), then auto-start Island
    /// even when Eat is unloaded (Campus / Study).
    private func watchMealWrapUps() async {
        guard let locations = diningStore.locations.value, !locations.isEmpty else { return }
        let fire = MealActivityWrapUpRefresh.nextFire(locations: locations)
        let delay = fire.timeIntervalSinceNow
        if delay > 0.05 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        await MealActivityAutoStartRunner.run(service: DiningService())
        wrapUpEpoch += 1
    }

    private func applyDeepLink(_ link: AnteatsDeepLink) {
        switch link.tab {
        case .eat: selection = .dining
        case .campus: selection = .campus
        // Gym cut from shipping IA until live ARC sensors exist — land on Eat.
        case .gym: selection = .dining
        case .study: selection = .busyness
        }
        pendingDeepLink = link.tab == .gym ? nil : link
    }

    // Visible labels are Eat / Campus / Study. Gym is parked (no tab) until
    // UCI/Occuspace confirms ARC sensors. Internal AppTab ids and -initialTab
    // launch args keep historical names for CI; `gym` maps to Eat.
    // Modern Tab syntax (iOS 18+) is required for Liquid Glass tab bar
    // behaviors like minimize-on-scroll.
    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Eat", systemImage: "fork.knife", value: AppTab.dining) {
                DiningView(
                    store: diningStore,
                    prefs: preferences,
                    plate: plate,
                    pendingDeepLink: $pendingDeepLink
                )
            }
            Tab("Campus", systemImage: "cup.and.saucer.fill", value: AppTab.campus) {
                CampusView(
                    store: campusStore,
                    prefs: preferences,
                    pendingDeepLink: $pendingDeepLink
                )
            }
            Tab("Study", systemImage: "books.vertical.fill", value: AppTab.busyness) {
                BusynessView(store: busynessStore, pendingDeepLink: $pendingDeepLink)
            }
        }
    }

    /// CI drives per-tab screenshots by launching with `-initialTab <tab>`.
    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-initialTab"), index + 1 < args.count,
           let tab = AppTab(rawValue: args[index + 1]) {
            // Gym tab removed from shipping — CI gym shots redirect to Eat.
            return tab == .gym ? .dining : tab
        }
        return .dining
    }
}

#Preview {
    RootTabView()
        .tint(.uciBlue)
}
