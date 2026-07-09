import SwiftUI

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
    case dining, gym, busyness
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
