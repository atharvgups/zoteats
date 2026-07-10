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

    /// nil lets SwiftUI follow the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct ZotEatsApp: App {
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.uciBlue)
                .preferredColorScheme(
                    (AppearanceSetting(rawValue: appearanceRaw) ?? .system).colorScheme
                )
        }
    }
}

enum AppTab: String, Hashable {
    case dining, gym, busyness, settings
}

struct RootTabView: View {
    @State private var selection: AppTab = RootTabView.initialTab()

    var body: some View {
        TabView(selection: $selection) {
            DiningView()
                .tabItem { Label("Dining", systemImage: "fork.knife") }
                .tag(AppTab.dining)

            GymView()
                .tabItem { Label("Gym", systemImage: "dumbbell.fill") }
                .tag(AppTab.gym)

            BusynessView()
                .tabItem { Label("Busyness", systemImage: "chart.bar.fill") }
                .tag(AppTab.busyness)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
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
