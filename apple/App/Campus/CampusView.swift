import SwiftUI
import ZotEatsKit

// Campus tab — retail dining beyond the two commons: Starbucks, Panda Express,
// Subway, Zot N Go markets, food courts. Hours and open/closed for everything;
// tapping a place with a published menu opens it with the same dietary
// filtering as Eat. Brand-app-only venues (most national chains) show hours
// plus a note, since they don't publish menus anywhere public.

struct CampusView: View {
    @State private var store = CampusStore()
    @State private var prefs = Preferences()
    @State private var selectedPlace: CampusPlace?
    @Environment(\.openSettings) private var openSettings

    private static let categoryOrder = ["Coffee & Cafés", "Food Courts", "Markets", "Restaurants & Pubs"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Campus", subtitle: "Coffee, food courts, and markets", onSettings: openSettings)
                    content
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.screen)
            .refreshable { await store.loadPlaces() }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarBackdrop()
            .sheet(item: $selectedPlace) { place in
                CampusMenuSheet(place: place, store: store, prefs: prefs)
            }
        }
        .task {
            await store.loadPlaces()
            // CI screenshots the menu sheet deterministically via
            // `-campusMenu <place-id>` instead of scripted taps.
            if let id = Self.autoOpenPlaceID,
               let place = store.places.value?.first(where: { $0.id == id }) {
                selectedPlace = place
            }
        }
    }

    private static var autoOpenPlaceID: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-campusMenu"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    @ViewBuilder
    private var content: some View {
        switch store.places {
        case .idle, .loading:
            VStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonCard(height: 64)
                }
            }
        case .failed(let message):
            EmptyStateView(
                icon: "cup.and.saucer",
                title: "Couldn't load campus spots",
                message: message,
                retry: { Task { await store.loadPlaces() } }
            )
            .zotCard()
        case .loaded(let places):
            if places.isEmpty {
                EmptyStateView(
                    icon: "cup.and.saucer",
                    title: "Nothing to show",
                    message: "No campus dining locations are listed right now."
                )
                .zotCard()
            } else {
                ForEach(groups(from: places), id: \.category) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.category)
                            .font(ZotFont.sectionTitle)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.places) { place in
                            CampusPlaceRow(place: place) {
                                selectedPlace = place
                                Haptics.selection()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Category groups in fixed order, open places first within each.
    private func groups(from places: [CampusPlace]) -> [(category: String, places: [CampusPlace])] {
        Self.categoryOrder.compactMap { category in
            let members = places
                .filter { $0.category == category }
                .sorted { lhs, rhs in
                    if lhs.openNow != rhs.openNow { return lhs.openNow }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            return members.isEmpty ? nil : (category, members)
        }
    }
}

// MARK: - Place row

private struct CampusPlaceRow: View {
    let place: CampusPlace
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(ZotFont.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(place.todayHours ?? "Closed today")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                StatusPill(isOpen: place.openNow)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("campus-place-\(place.id)")
        .zotCard()
        .accessibilityLabel(
            "\(place.name), \(place.openNow ? "open" : "closed")\(place.todayHours.map { ", today \($0)" } ?? "")"
        )
        .accessibilityHint("Shows menu and details")
    }
}

// MARK: - Menu sheet

struct CampusMenuSheet: View {
    let place: CampusPlace
    let store: CampusStore
    let prefs: Preferences

    @Environment(\.dismiss) private var dismiss

    private static let dietFilters = ["Vegan", "Vegetarian", "Halal", "Kosher", "Gluten-Free"]
    @State private var dietFilter: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name)
                            .font(ZotFont.hero(24))
                            .padding(.trailing, 44)
                        HStack(spacing: 8) {
                            StatusPill(isOpen: place.openNow)
                            Text(place.todayHours ?? "Closed today")
                                .font(ZotFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    menuContent
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.screen)
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
                .accessibilityLabel("Close")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            dietFilter = prefs.dietFilter
            await store.loadMenu(for: place.id)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        switch store.menuState(for: place.id) {
        case .idle, .loading:
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: 72)
                }
            }
            .padding(.horizontal, 20)
        case .failed:
            noMenuNote
        case .loaded(let stations):
            if stations.isEmpty {
                noMenuNote
            } else {
                PillRow(
                    items: Self.dietFilters,
                    title: { $0 },
                    selection: $dietFilter,
                    allowsDeselect: true
                )
                .accessibilityLabel("Dietary filter")

                let filtered = filteredStations(stations)
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "Nothing matches that filter",
                        message: "Try clearing the dietary filter."
                    )
                } else {
                    ForEach(filtered) { station in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(station.name)
                                .font(ZotFont.sectionTitle)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(station.items) { item in
                                CampusMenuItemRow(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private var noMenuNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "menucard")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("No published menu")
                .font(ZotFont.sectionTitle)
            Text("\(place.name) doesn't post its menu here — check the brand's own app for ordering.")
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    private func filteredStations(_ stations: [MenuStation]) -> [MenuStation] {
        guard let dietFilter else { return stations }
        return stations.compactMap { station in
            let items = station.items.filter { $0.dietaryTags.contains(dietFilter) }
            return items.isEmpty ? nil : MenuStation(name: station.name, items: items)
        }
    }
}

// MARK: - Menu item row

private struct CampusMenuItemRow: View {
    let item: MenuItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(ZotFont.body.weight(.semibold))
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !item.dietaryTags.isEmpty || !item.allergens.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(item.dietaryTags, id: \.self) { tag in
                                TagChip(text: tag, color: TagPalette.dietColor(tag))
                            }
                            ForEach(item.allergens, id: \.self) { allergen in
                                TagChip(text: allergen, color: TagPalette.allergenColor)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let calories = item.calories {
                VStack(spacing: -1) {
                    Text("\(calories)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.uciBlue)
                    Text("cal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.uciBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityLabel("\(calories) calories")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }
}

#Preview {
    CampusView()
}
