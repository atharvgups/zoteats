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
}

/// Applies the appearance by setting the hosting window's interface style directly —
/// deterministic, flips live, and avoids SwiftUI preferredColorScheme re-layout issues.
private struct AppearanceApplier: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        // The window isn't attached yet during the first update; defer one runloop turn.
        DispatchQueue.main.async {
            view.window?.overrideUserInterfaceStyle = style
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
    case dining, gym, busyness, settings
}

struct RootTabView: View {
    @State private var selection: AppTab = RootTabView.initialTab()

    // Observed here (not on the App struct) so the theme flips reactively
    // the moment Settings writes a new appearance value.
    @AppStorage(AppearanceSetting.storageKey)
    private var appearanceRaw: String = AppearanceSetting.system.rawValue

    var body: some View {
        tabs
            .background(
                AppearanceApplier(
                    style: (AppearanceSetting(rawValue: appearanceRaw) ?? .system).interfaceStyle
                )
            )
    }

    private var tabs: some View {
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
