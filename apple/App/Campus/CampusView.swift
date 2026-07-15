import SwiftUI
import ZotEatsKit

// Campus tab — retail dining beyond the two commons: Starbucks, Panda Express,
// Subway, Zot N Go markets, food courts. Hours and open/closed for everything;
// tapping a place with a published menu opens it with the same dietary
// filtering as Eat. Brand-app-only venues (most national chains) show hours
// plus a note, since they don't publish menus anywhere public.

struct CampusView: View {
    let store: CampusStore
    let prefs: Preferences
    @State private var selectedPlace: CampusPlace?
    /// Nil = all categories.
    @State private var categoryFilter: String?
    /// Everything shows by default; the chip narrows to open places on demand.
    @State private var openOnly = false
    @Environment(\.openSettings) private var openSettings

    private static let categoryOrder = ["Coffee & Cafés", "Food Courts", "Markets", "Restaurants & Pubs"]
    private static let categoryShortNames = [
        "Coffee & Cafés": "Coffee",
        "Food Courts": "Food Courts",
        "Markets": "Markets",
        "Restaurants & Pubs": "Pubs",
    ]

    // No NavigationStack: nothing navigates, and a flat hierarchy lets the
    // iOS 26 glass tab bar track this scroll view directly (minimize-on-scroll).
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Campus", subtitle: "Coffee, food courts, and markets", onSettings: openSettings)

                filterBar

                content
                    .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.screen)
        .refreshable { await store.loadPlaces() }
        .statusBarBackdrop()
        .sheet(item: $selectedPlace) { place in
            CampusMenuSheet(place: place, store: store, prefs: prefs)
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

    /// One row of controls replaces the old endless stacked sections:
    /// category pills narrow the list, "Open now" hides what you can't use.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                openNowChip
                Divider()
                    .frame(height: 22)
                ForEach(Self.categoryOrder, id: \.self) { category in
                    let isSelected = categoryFilter == category
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            categoryFilter = isSelected ? nil : category
                        }
                        Haptics.selection()
                    } label: {
                        Text(Self.categoryShortNames[category] ?? category)
                            .font(ZotFont.pill.weight(isSelected ? .semibold : .medium))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? Color.uciBlue.opacity(0.12) : Color.card,
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? Color.uciBlue : .primary)
                            .overlay(
                                Capsule().strokeBorder(
                                    isSelected ? Color.uciBlue.opacity(0.35) : Color.cardBorder,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Filter campus spots")
    }

    private var openNowChip: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                openOnly.toggle()
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(openOnly ? Color.openGreen : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("Open now")
                    .font(ZotFont.pill.weight(openOnly ? .semibold : .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                openOnly ? Color.openGreen.opacity(0.12) : Color.card,
                in: Capsule()
            )
            .foregroundStyle(openOnly ? Color.openGreen : .primary)
            .overlay(
                Capsule().strokeBorder(
                    openOnly ? Color.openGreen.opacity(0.35) : Color.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(openOnly ? "Showing open spots only" : "Showing all spots")
        .accessibilityHint("Toggles closed spots")
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
            let brands = filteredBrands(from: places)
            if brands.isEmpty {
                if openOnly {
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: "Nothing's open right now",
                        message: categoryFilter == nil
                            ? "Every campus spot is closed at the moment."
                            : "Nothing in this category is open at the moment.",
                        actionTitle: "Show closed spots",
                        retry: { withAnimation(.snappy(duration: 0.25)) { openOnly = false } }
                    )
                    .zotCard()
                } else {
                    EmptyStateView(
                        icon: "cup.and.saucer",
                        title: "Nothing to show",
                        message: "No campus dining locations are listed right now."
                    )
                    .zotCard()
                }
            } else {
                ForEach(brands, id: \.brand) { entry in
                    if entry.places.count == 1 {
                        CampusPlaceRow(place: entry.places[0], showBrandOnly: false) {
                            selectedPlace = entry.places[0]
                            Haptics.selection()
                        }
                    } else {
                        CampusBrandGroupRow(brand: entry.brand, places: entry.places) { place in
                            selectedPlace = place
                            Haptics.selection()
                        }
                    }
                }
            }
        }
    }

    /// One flat brand-grouped list driven by the filter bar: category pills
    /// replace section headers, open places sort first, chains stay collapsed
    /// into expandable brand rows.
    private func filteredBrands(
        from places: [CampusPlace]
    ) -> [(brand: String, places: [CampusPlace])] {
        var filtered = places
        if let categoryFilter {
            filtered = filtered.filter { $0.category == categoryFilter }
        }
        if openOnly {
            filtered = filtered.filter(\.openNow)
        }

        var order: [String] = []
        var byBrand: [String: [CampusPlace]] = [:]
        for place in filtered {
            if byBrand[place.brand] == nil { order.append(place.brand) }
            byBrand[place.brand, default: []].append(place)
        }
        return order
            .map { brand in
                (brand: brand, places: byBrand[brand]!.sorted { lhs, rhs in
                    if lhs.openNow != rhs.openNow { return lhs.openNow }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                })
            }
            .sorted { lhs, rhs in
                let lhsOpen = lhs.places.contains(where: \.openNow)
                let rhsOpen = rhs.places.contains(where: \.openNow)
                if lhsOpen != rhsOpen { return lhsOpen }
                return lhs.brand.localizedCaseInsensitiveCompare(rhs.brand) == .orderedAscending
            }
    }
}

// MARK: - Expandable multi-location brand row

private struct CampusBrandGroupRow: View {
    let brand: String
    let places: [CampusPlace]
    let onOpen: (CampusPlace) -> Void

    @State private var isExpanded = false

    private var openCount: Int { places.filter(\.openNow).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
                Haptics.selection()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(brand)
                            .font(ZotFont.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(places.count) locations")
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    StatusPill(
                        isOpen: openCount > 0,
                        openText: openCount == places.count ? "Open" : "\(openCount) open",
                        closedText: "Closed"
                    )
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(brand), \(places.count) locations, \(openCount) open")
            .accessibilityHint(isExpanded ? "Hides locations" : "Shows locations")

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(places) { place in
                        Button {
                            onOpen(place)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.locationDetail ?? place.name)
                                        .font(ZotFont.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(place.todayHours ?? "Closed today")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 6)
                                StatusPill(isOpen: place.openNow)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(brand) at \(place.locationDetail ?? place.name), \(place.openNow ? "open" : "closed")"
                        )
                        .accessibilityHint("Shows details")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .zotCard()
    }
}

// MARK: - Place row

private struct CampusPlaceRow: View {
    let place: CampusPlace
    var showBrandOnly = true
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(showBrandOnly ? place.brand : place.name)
                            .font(ZotFont.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if place.hasMenu {
                            TagChip(text: "Menu", color: .uciBlue)
                        }
                    }
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
            "\(place.name), \(place.openNow ? "open" : "closed")\(place.todayHours.map { ", today \($0)" } ?? "")\(place.hasMenu ? ", menu available" : "")"
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(ZotFont.body.weight(.semibold))
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
                .background(Color.uciBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous))
                .accessibilityLabel("\(calories) calories")
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }
}

#Preview {
    CampusView(store: CampusStore(), prefs: Preferences())
}
