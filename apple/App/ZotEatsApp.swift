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
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.uciBlue)
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

    var body: some View {
        tabs
            .environment(\.openSettings) { showSettings = true }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                // Restore the persisted appearance once the window hierarchy exists.
                AppearanceSetting.saved.apply()
            }
    }

    // Visible labels are Eat / Gym / Crowds; internal AppTab ids and the
    // -initialTab launch args keep their historical names for CI stability.
    private var tabs: some View {
        TabView(selection: $selection) {
            DiningView()
                .tabItem { Label("Eat", systemImage: "fork.knife") }
                .tag(AppTab.dining)

            CampusView()
                .tabItem { Label("Campus", systemImage: "cup.and.saucer.fill") }
                .tag(AppTab.campus)

            GymView()
                .tabItem { Label("Gym", systemImage: "dumbbell.fill") }
                .tag(AppTab.gym)

            BusynessView()
                .tabItem { Label("Study", systemImage: "books.vertical.fill") }
                .tag(AppTab.busyness)
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
