import SwiftUI
import ZotEatsKit

// The "watchlist" picker behind Settings → Notifications → Opening alerts.
// Pick any dining hall or campus spot; iOS pings you the moment it opens.

struct OpeningAlertsPicker: View {
    @Environment(\.dismiss) private var dismiss

    /// Parent binding so the Settings row count updates live.
    @Binding var watched: Set<String>

    @State private var halls: [DiningLocation] = []
    @State private var places: [CampusPlace] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        title: "Opening Alerts",
                        subtitle: "Get pinged the moment a spot opens"
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        searchField

                        if permissionDenied {
                            Text("Notifications are turned off for ZotEats in iOS Settings — enable them there first.")
                                .font(ZotFont.caption)
                                .foregroundStyle(TagPalette.terracotta)
                        }

                        if isLoading && halls.isEmpty && places.isEmpty {
                            SkeletonCard(height: 200)
                        } else {
                            if !filteredHalls.isEmpty {
                                section(title: "Dining Halls") {
                                    ForEach(filteredHalls) { hall in
                                        placeRow(
                                            id: "dining:\(hall.id)",
                                            name: hall.name,
                                            detail: hall.todayHours ?? "Closed today"
                                        )
                                        if hall.id != filteredHalls.last?.id { Divider() }
                                    }
                                }
                            }
                            ForEach(campusCategories, id: \.self) { category in
                                let group = filteredPlaces.filter { $0.category == category }
                                if !group.isEmpty {
                                    section(title: category) {
                                        ForEach(group) { place in
                                            placeRow(
                                                id: "campus:\(place.id)",
                                                name: place.name,
                                                detail: place.todayHours ?? "Closed today"
                                            )
                                            if place.id != group.last?.id { Divider() }
                                        }
                                    }
                                }
                            }
                            if filteredHalls.isEmpty && filteredPlaces.isEmpty {
                                EmptyStateView(
                                    icon: "magnifyingglass",
                                    title: "No spots match",
                                    message: "Try a different name — halls, cafés, and markets are all here."
                                )
                            }
                        }
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
                .accessibilityLabel("Close opening alerts")
            }
            .task { await load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func placeRow(id: String, name: String, detail: String) -> some View {
        Toggle(isOn: binding(for: id)) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(ZotFont.body)
                    .lineLimit(1)
                Text(detail)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tint(.uciBlue)
        .padding(.vertical, 6)
        .accessibilityIdentifier("openAlert-\(id)")
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { watched.contains(id) },
            set: { on in
                guard on else {
                    watched.remove(id)
                    OpeningAlerts.setWatching(id, false)
                    return
                }
                Task {
                    guard await FavoriteAlerts.requestPermission() else {
                        permissionDenied = true
                        return
                    }
                    permissionDenied = false
                    watched.insert(id)
                    OpeningAlerts.setWatching(id, true)
                    Haptics.soft()
                }
            }
        )
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ZotFont.sectionTitle)
            VStack(spacing: 4, content: content)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search spots", text: $searchText)
                .font(ZotFont.body)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Data

    private var filteredHalls: [DiningLocation] {
        guard !query.isEmpty else { return halls }
        return halls.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredPlaces: [CampusPlace] {
        guard !query.isEmpty else { return places }
        return places.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var campusCategories: [String] {
        var seen = Set<String>()
        return filteredPlaces.map(\.category).filter { seen.insert($0).inserted }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private func load() async {
        async let hallsTask = DiningService().locations()
        async let placesTask = (try? CampusService().places()) ?? []
        halls = await hallsTask
        places = await placesTask
        isLoading = false
    }
}

#Preview {
    OpeningAlertsPicker(watched: .constant([]))
}
