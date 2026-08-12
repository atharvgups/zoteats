import SwiftUI
import ZotEatsKit

// Campus tab — retail dining beyond the two commons: Starbucks, Panda Express,
// Subway, Zot N Go markets, food courts. Hours and open/closed for everything;
// tapping a place with a published menu opens it with the same dietary
// filtering as Eat. Brand-app-only venues (most national chains) show hours
// plus a note, since they don't publish menus anywhere public.
//
// IA (Atharv): distinct Favorites shelf; favorited places are removed from the
// main list (no double cards). Twisted Root sorts first among remaining
// non-favorited Campus rows (owner vegan preference).

struct CampusView: View {
    let store: CampusStore
    let prefs: Preferences
    @Binding var pendingDeepLink: AnteatsDeepLink?
    @State private var selectedPlace: CampusPlace?
    @State private var typeFilter: CampusTypeFilter = .all
    /// Everything shows by default; the chip narrows to open places on demand.
    @State private var openOnly = false
    /// Bumps after each open/close tick so pills / Open-now filter re-render.
    @State private var boundaryEpoch = 0
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase

    private var boundaryWatchID: String {
        "\(boundaryEpoch)|\(store.places.value?.map(\.id).joined() ?? "")"
    }

    // No NavigationStack: nothing navigates, and a flat hierarchy lets the
    // iOS 26 glass tab bar track this scroll view directly (minimize-on-scroll).
    var body: some View {
        // Status pills / hoursLine / Open-now filter read openNow from the store;
        // re-render after each boundary tick.
        let _ = boundaryEpoch
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
        .refreshable {
            await store.loadPlaces()
            boundaryEpoch += 1
        }
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
            applyPendingDeepLinkIfNeeded()
        }
        .task(id: boundaryWatchID) {
            await watchOpenBoundaries()
        }
        .onChange(of: store.places.value) {
            applyPendingDeepLinkIfNeeded()
        }
        .onChange(of: pendingDeepLink) {
            applyPendingDeepLinkIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                boundaryEpoch += 1
            }
        }
    }

    /// Sleep until the next café open/close / tomorrow open / midnight, then
    /// recompute openNow from cached schedules (same honesty as the widget).
    private func watchOpenBoundaries() async {
        guard let places = store.places.value, !places.isEmpty else { return }
        let fire = CampusOpenReload.nextReload(now: .now, places: places)
        let delay = fire.timeIntervalSinceNow
        if delay > 0.05 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        await store.loadPlaces()
        boundaryEpoch += 1
    }

    private func applyPendingDeepLinkIfNeeded() {
        guard let link = pendingDeepLink, link.tab == .campus else { return }
        let feedReady: Bool = {
            switch store.places {
            case .loaded, .failed: return true
            case .idle, .loading: return false
            }
        }()
        switch CampusDeepLinkApply.resolve(
            placeID: link.placeID,
            places: store.places.value,
            feedReady: feedReady
        ) {
        case .waitForPlaces:
            return
        case .discard:
            pendingDeepLink = nil
        case .open(let placeID):
            guard let place = store.places.value?.first(where: { $0.id == placeID }) else {
                pendingDeepLink = nil
                return
            }
            openOnly = false
            typeFilter = .all
            selectedPlace = place
            pendingDeepLink = nil
        }
    }

    /// Open now + compact type chips (All / Coffee / Food / Markets).
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                openNowChip
                Divider()
                    .frame(height: 22)
                ForEach(CampusTypeFilter.allCases, id: \.self) { filter in
                    let isSelected = typeFilter == filter
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            typeFilter = filter
                        }
                        Haptics.selection()
                    } label: {
                        Text(filter.title)
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
                    .accessibilityLabel(filter.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityHint(
                        filter == .all
                            ? "Shows all campus types"
                            : (isSelected ? "Already filtering to \(filter.title)" : "Filters to \(filter.title)")
                    )
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
        .accessibilityLabel(CampusOpenNowAccessibility.label(openOnly: openOnly))
        .accessibilityAddTraits(openOnly ? .isSelected : [])
        .accessibilityHint(CampusOpenNowAccessibility.hint(openOnly: openOnly))
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
            let filtered = filteredPlaces(from: places)
            let partition = CampusPlaceSort.partition(
                places: filtered,
                favoriteIDs: prefs.favoriteCampusPlaceIDs
            )
            let brands = CampusPlaceSort.brandGroups(from: partition.main)

            if partition.favorites.isEmpty && brands.isEmpty {
                emptyState(for: places)
            } else {
                if !partition.favorites.isEmpty {
                    favoritesShelf(partition.favorites)
                }

                ForEach(brands, id: \.brand) { entry in
                    if entry.places.count == 1 {
                        CampusPlaceRow(
                            place: entry.places[0],
                            showBrandOnly: false,
                            isFavorite: prefs.isCampusFavorite(entry.places[0].id),
                            onToggleFavorite: { prefs.toggleCampusFavorite(entry.places[0].id) }
                        ) {
                            selectedPlace = entry.places[0]
                            Haptics.selection()
                        }
                    } else {
                        CampusBrandGroupRow(
                            brand: entry.brand,
                            places: entry.places,
                            favoriteIDs: prefs.favoriteCampusPlaceIDs,
                            onToggleFavorite: { prefs.toggleCampusFavorite($0) }
                        ) { place in
                            selectedPlace = place
                            Haptics.selection()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(for places: [CampusPlace]) -> some View {
        let short = typeFilter == .all ? nil : typeFilter.title
        switch CampusListEmptyAction.resolve(
            hasCategoryFilter: typeFilter != .all,
            openOnly: openOnly
        ) {
        case .clearCategory:
            let inFilter = CampusCategoryEmptyCopy.places(matching: typeFilter, from: places)
            let hint = openOnly ? CampusNextOpenHint.best(from: inFilter) : nil
            EmptyStateView(
                icon: openOnly ? "moon.zzz" : "line.3.horizontal.decrease.circle",
                title: openOnly
                    ? "Nothing's open in \(short ?? "this filter")"
                    : "Nothing in \(short ?? "this filter")",
                message: CampusCategoryEmptyCopy.message(openOnly: openOnly, hint: hint),
                actionTitle: "Clear filter",
                retry: {
                    withAnimation(.snappy(duration: 0.25)) { typeFilter = .all }
                    Haptics.selection()
                }
            )
            .zotCard()
            .accessibilityIdentifier("campus-clear-category")
        case .showClosed:
            let hint = CampusNextOpenHint.best(from: places)
            EmptyStateView(
                icon: "moon.zzz",
                title: "Nothing's open right now",
                message: hint?.line
                    ?? "Every campus spot is closed at the moment.",
                actionTitle: "Show closed spots",
                retry: { withAnimation(.snappy(duration: 0.25)) { openOnly = false } }
            )
            .zotCard()
        case .none:
            EmptyStateView(
                icon: "cup.and.saucer",
                title: "Nothing to show",
                message: "No campus dining locations are listed right now."
            )
            .zotCard()
        }
    }

    private func favoritesShelf(_ favorites: [CampusPlace]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(ZotFont.sectionTitle)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 6) {
                ForEach(favorites) { place in
                    CampusFavoriteShelfRow(
                        place: place,
                        onToggleFavorite: { prefs.toggleCampusFavorite(place.id) }
                    ) {
                        selectedPlace = place
                        Haptics.selection()
                    }
                }
            }
        }
        .padding(.bottom, 4)
        .animation(.snappy(duration: 0.25), value: prefs.favoriteCampusPlaceIDs)
    }

    private func filteredPlaces(from places: [CampusPlace]) -> [CampusPlace] {
        var filtered = places.filter { typeFilter.matches(category: $0.category) }
        if openOnly {
            filtered = filtered.filter(\.openNow)
        }
        return filtered
    }
}

// MARK: - Compact Favorites shelf

private struct CampusFavoriteShelfRow: View {
    let place: CampusPlace
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(place.name)
                                .font(ZotFont.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if place.hasMenu {
                                TagChip(text: "Menu", color: .uciBlue)
                            }
                        }
                        Text(place.hoursLine)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    StatusPill(isOpen: place.openNow)
                    if place.hasMenu {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.uciBlue)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from Favorites")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .zotCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("campus-favorite-\(place.id)")
    }
}

// MARK: - Expandable multi-location brand row

private struct CampusBrandGroupRow: View {
    let brand: String
    let places: [CampusPlace]
    let favoriteIDs: Set<String>
    let onToggleFavorite: (String) -> Void
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
                        HStack(spacing: 8) {
                            Button {
                                onOpen(place)
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.locationDetail ?? place.name)
                                            .font(ZotFont.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(place.hoursLine)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 6)
                                    StatusPill(isOpen: place.openNow)
                                    if place.hasMenu {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
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
                                CampusPlaceAccessibilityLabel.nested(
                                    brand: brand,
                                    locationDetail: place.locationDetail ?? place.name,
                                    openNow: place.openNow,
                                    hoursLine: place.hoursLine
                                )
                            )
                            .accessibilityHint(place.hasMenu ? "Shows menu and details" : "Shows details")

                            Button {
                                onToggleFavorite(place.id)
                            } label: {
                                Image(systemName: favoriteIDs.contains(place.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(favoriteIDs.contains(place.id) ? Color.uciBlue : Color.secondary.opacity(0.45))
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                favoriteIDs.contains(place.id) ? "Remove from Favorites" : "Add to Favorites"
                            )
                        }
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
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
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
                        Text(place.hoursLine)
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    StatusPill(isOpen: place.openNow)
                    if place.hasMenu {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFavorite ? Color.uciBlue : .tertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
            .padding(.trailing, 8)
        }
        .zotCard()
        .accessibilityIdentifier("campus-place-\(place.id)")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            CampusPlaceAccessibilityLabel.place(
                name: place.name,
                openNow: place.openNow,
                hoursLine: place.hoursLine,
                hasMenu: place.hasMenu
            )
        )
        .accessibilityHint(place.hasMenu ? "Shows menu and details" : "Shows details")
    }
}

// MARK: - Menu sheet

struct CampusMenuSheet: View {
    let place: CampusPlace
    let store: CampusStore
    let prefs: Preferences

    @Environment(\.dismiss) private var dismiss
    @State private var showDietFilters = false
    @State private var allDayExpanded = false

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
                            Text(place.hoursLine)
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
        .sheet(isPresented: $showDietFilters) {
            DietFilterSheet(prefs: prefs)
        }
        .task {
            // Honest empty for brand-app-only venues — don't fetch a menu we know is absent.
            guard place.hasMenu else { return }
            await store.loadMenu(for: place.id)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if !place.hasMenu {
            noMenuNote(published: false)
        } else {
            switch store.menuState(for: place.id) {
            case .idle, .loading:
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard(height: 72)
                    }
                }
                .padding(.horizontal, 20)
            case .failed:
                noMenuNote(published: true)
            case .loaded(let stations):
                if stations.isEmpty {
                    noMenuNote(published: true)
                } else {
                    filtersChip
                        .padding(.horizontal, 20)

                    let filtered = filteredStations(stations)
                    if filtered.isEmpty {
                        // Same Eat Filters prefs as Dining — reuse honest empty copy (no search on Campus menus).
                        if let copy = EatFilterEmptyCopy.resolve(
                            hasSearch: false,
                            hasMenuFilters: prefs.hasActiveMenuFilters
                        ) {
                            EmptyStateView(
                                icon: "ant",
                                title: copy.title,
                                message: copy.message,
                                actionTitle: copy.actionTitle,
                                retry: {
                                    prefs.clearMenuFilters()
                                    Haptics.selection()
                                }
                            )
                        } else {
                            noMenuNote(published: true)
                        }
                    } else {
                        ForEach(filtered) { station in
                            stationBlock(station)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stationBlock(_ station: MenuStation) -> some View {
        let isAllDay = CampusMenuNormalize.isAvailableAllDay(station.name)
        VStack(alignment: .leading, spacing: 8) {
            if isAllDay {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        allDayExpanded.toggle()
                    }
                    Haptics.selection()
                } label: {
                    HStack {
                        Text(station.name)
                            .font(ZotFont.sectionTitle)
                        Spacer()
                        Text("\(station.items.count)")
                            .font(ZotFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(allDayExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(station.name), \(station.items.count) items")
                .accessibilityHint(allDayExpanded ? "Hides items" : "Shows items")
                .accessibilityAddTraits(.isHeader)

                if allDayExpanded {
                    ForEach(station.items) { item in
                        CampusMenuItemRow(item: item)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                Text(station.name)
                    .font(ZotFont.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                ForEach(station.items) { item in
                    CampusMenuItemRow(item: item)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// Same Filters chip language as Eat — shared prefs, not a local single-select.
    private var filtersChip: some View {
        let diets = prefs.dietFilters.sorted()
        let allergens = prefs.allergenAvoids.sorted()
        let label = MenuFiltersChipAccessibility.title(
            dietFilters: diets,
            allergenAvoids: allergens
        )
        let active = prefs.hasActiveMenuFilters
        return Button {
            showDietFilters = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(ZotFont.pill.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                active ? Color.uciBlue.opacity(0.12) : Color.primary.opacity(0.05),
                in: Capsule()
            )
            .foregroundStyle(active ? Color.uciBlue : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("campus-diet-filter-chip")
        .accessibilityLabel(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: diets,
                allergenAvoids: allergens
            )
        )
    }

    private func noMenuNote(published: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "menucard")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(published ? "Menu not posted" : "No published menu")
                .font(ZotFont.sectionTitle)
            Text(
                published
                    ? "\(place.name) usually posts a menu here, but nothing is listed for today yet."
                    : "\(place.name) doesn't post its menu here — check the brand's own app for ordering."
            )
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    private func filteredStations(_ stations: [MenuStation]) -> [MenuStation] {
        MenuFilterMatching.filterStations(
            stations,
            dietFilters: prefs.dietFilters,
            allergenAvoids: prefs.allergenAvoids
        )
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
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DishRowAccessibility.label(
                dishName: item.name,
                calories: item.calories,
                dietaryTags: item.dietaryTags,
                allergens: item.allergens
            )
        )
    }
}

#Preview {
    CampusView(store: CampusStore(), prefs: Preferences(), pendingDeepLink: .constant(nil))
}
