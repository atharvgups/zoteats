import SwiftUI
import ZotEatsKit

// The dining-hall watchlist behind Settings → Alerts → Halls to watch.

struct OpeningAlertsPicker: View {
    @Environment(\.dismiss) private var dismiss

    /// Parent binding so the Settings row count updates live.
    @Binding var watched: Set<String>

    @State private var halls: [DiningLocation] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        title: "Halls to watch",
                        subtitle: "Ping these dining halls at meal start and closing soon"
                    )

                    VStack(alignment: .leading, spacing: 16) {
                        searchField

                        if permissionDenied {
                            Text("Notifications are turned off for Anteats in iOS Settings — enable them there first.")
                                .font(ZotFont.caption)
                                .foregroundStyle(TagPalette.terracotta)
                        }

                        if isLoading && halls.isEmpty {
                            SkeletonCard(height: 200)
                        } else {
                            if !filteredHalls.isEmpty {
                                section(title: "Dining Halls") {
                                    ForEach(filteredHalls) { hall in
                                        placeRow(
                                            id: "dining:\(hall.id)",
                                            name: hall.name,
                                            detail: hall.hoursLine()
                                        )
                                        if hall.id != filteredHalls.last?.id { ZotHairline(leading: 0) }
                                    }
                                }
                            }
                            if filteredHalls.isEmpty {
                                EmptyStateView(
                                    icon: "magnifyingglass",
                                    title: "No halls match",
                                    message: "Try Anteatery, Brandywine, or Oasis."
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
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
        .toggleStyle(.switch)
        .tint(Color.accent)
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
            TextField("Search halls", text: $searchText)
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

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private func load() async {
        halls = await DiningService().locations()
        isLoading = false
    }
}

#Preview {
    OpeningAlertsPicker(watched: .constant([]))
}
