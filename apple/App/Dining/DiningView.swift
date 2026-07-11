import SwiftUI
import ZotEatsKit

// The Dining tab — ZotEats' hero surface.
// Hall hero cards -> meal period pills -> dietary filters -> live menu by station.

struct DiningView: View {
    @State private var store = DiningStore()
    @State private var prefs = Preferences()
    @Environment(\.openSettings) private var openSettings

    @State private var selectedHall: DiningLocationID = .anteatery
    @State private var selectedPeriod: String?
    @State private var searchText = ""
    @State private var selectedDish: MenuItem?

    private static let dietFilters = ["Vegan", "Vegetarian", "Halal", "Kosher", "Gluten-Free"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Eat", subtitle: Self.greeting(), onSettings: openSettings)

                    hallSelector
                        .padding(.horizontal, 20)

                    content
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.screen.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search today's dishes"
            )
            .refreshable { await refresh() }
            .task { await store.loadLocations() }
            .task(id: menuTaskID) { await loadCurrentMenu() }
            .onChange(of: store.locations.value) { syncPeriodSelection() }
            .onChange(of: selectedHall) { syncPeriodSelection() }
            .sheet(item: $selectedDish) { dish in
                DishDetailSheet(dish: dish, prefs: prefs)
            }
        }
    }

    // MARK: - Derived state

    private var selectedLocation: DiningLocation? {
        store.locations.value?.first { $0.id == selectedHall }
    }

    private var currentMenuState: LoadState<DiningMenu> {
        guard let selectedPeriod else { return .idle }
        return store.menuState(hall: selectedHall, period: selectedPeriod)
    }

    /// Drives `.task(id:)` so the menu reloads whenever hall or period changes.
    private var menuTaskID: String {
        "\(selectedHall.rawValue)|\(selectedPeriod ?? "-")"
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveFilter: Bool {
        prefs.dietFilter != nil || !trimmedQuery.isEmpty
    }

    // MARK: - Sections

    @ViewBuilder
    private var content: some View {
        switch store.locations {
        case .idle, .loading:
            loadingPlaceholder
        case .failed(let message):
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Can't reach UCI Dining",
                message: message
            ) {
                Task { await refresh() }
            }
        case .loaded:
            if let location = selectedLocation, !location.availablePeriods.isEmpty {
                PillRow(
                    items: location.availablePeriods,
                    title: { $0 },
                    selection: $selectedPeriod
                )
                .accessibilityLabel("Meal period")
            }

            PillRow(
                items: Self.dietFilters,
                title: { $0 },
                selection: $prefs.dietFilter,
                allowsDeselect: true
            )
            .accessibilityLabel("Dietary filter")

            menuContent
        }
    }

    private var hallSelector: some View {
        HStack(spacing: 12) {
            ForEach(DiningLocationID.allCases) { hall in
                HallCard(
                    hall: hall,
                    location: store.locations.value?.first { $0.id == hall },
                    isSelected: hall == selectedHall
                ) {
                    guard hall != selectedHall else { return }
                    withAnimation(.snappy(duration: 0.3)) {
                        selectedHall = hall
                    }
                    Haptics.selection()
                }
            }
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        switch currentMenuState {
        case .idle, .loading:
            loadingPlaceholder
        case .failed(let message):
            EmptyStateView(
                icon: "fork.knife.circle",
                title: "Menu unavailable",
                message: message
            ) {
                Task { await loadCurrentMenu() }
            }
        case .loaded(let menu):
            let stations = filteredStations(menu)
            if stations.isEmpty {
                if hasActiveFilter {
                    EmptyStateView(
                        icon: trimmedQuery.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass",
                        title: "Nothing matches that filter",
                        message: "Try a different search or clear your dietary filter."
                    )
                } else {
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: "No menu posted",
                        message: "\(selectedHall.displayName) hasn't published \(menu.period.lowercased()) yet. Check back soon."
                    )
                }
            } else {
                menuList(menu: menu, stations: stations)
            }
        }
    }

    private func menuList(menu: DiningMenu, stations: [MenuStation]) -> some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            Text("\(menu.period) • \(prettyDate(menu.date))")
                .font(ZotFont.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)

            let favorites = favoriteItems(in: stations)
            if !favorites.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        title: "Favorites today",
                        count: favorites.count,
                        icon: "heart.fill",
                        tint: .pink
                    )
                    ForEach(favorites) { item in
                        dishRow(item)
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }

            ForEach(stations) { station in
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: station.name, count: station.items.count)
                    ForEach(station.items) { item in
                        dishRow(item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .animation(.snappy(duration: 0.25), value: prefs.favoriteDishNames)
    }

    private func dishRow(_ item: MenuItem) -> some View {
        DishRowCard(
            item: item,
            isFavorite: prefs.isFavorite(item.name),
            onToggleFavorite: { prefs.toggleFavorite(item.name) },
            onOpen: { selectedDish = item }
        )
        .accessibilityIdentifier("dish-row")
    }

    private func sectionHeader(
        title: String,
        count: Int,
        icon: String? = nil,
        tint: Color = .uciGold
    ) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: 4, height: 16)
            }
            Text(title)
                .font(ZotFont.sectionTitle)
            Spacer()
            Text("\(count)")
                .font(ZotFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .accessibilityLabel("\(count) dishes")
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(height: 96)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityLabel("Loading menu")
    }

    // MARK: - Filtering

    private func matches(_ item: MenuItem) -> Bool {
        if let filter = prefs.dietFilter, !item.dietaryTags.contains(filter) {
            return false
        }
        let query = trimmedQuery
        guard !query.isEmpty else { return true }
        if item.name.localizedCaseInsensitiveContains(query) { return true }
        return item.description?.localizedCaseInsensitiveContains(query) ?? false
    }

    private func filteredStations(_ menu: DiningMenu) -> [MenuStation] {
        menu.stations.compactMap { station in
            let items = station.items.filter(matches)
            return items.isEmpty ? nil : MenuStation(name: station.name, items: items)
        }
    }

    /// Favorited dishes being served right now, deduplicated by name.
    private func favoriteItems(in stations: [MenuStation]) -> [MenuItem] {
        var seen = Set<String>()
        var result: [MenuItem] = []
        for station in stations {
            for item in station.items where prefs.isFavorite(item.name) && seen.insert(item.name).inserted {
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Loading

    private func loadCurrentMenu() async {
        guard let selectedPeriod else { return }
        await store.loadMenu(hall: selectedHall, period: selectedPeriod)
    }

    private func refresh() async {
        await store.loadLocations()
        syncPeriodSelection()
        await loadCurrentMenu()
    }

    /// Keeps the period selection valid for the current hall,
    /// preferring the meal most likely happening now.
    private func syncPeriodSelection() {
        guard let location = selectedLocation else { return }
        if let selectedPeriod, location.availablePeriods.contains(selectedPeriod) { return }
        selectedPeriod = defaultPeriod(for: location)
    }

    private func defaultPeriod(for location: DiningLocation) -> String? {
        let periods = location.availablePeriods
        guard !periods.isEmpty else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let hour = calendar.component(.hour, from: .now)

        let preferred: String
        switch hour {
        case ..<10: preferred = "Breakfast"
        case ..<15: preferred = "Lunch"
        case ..<21: preferred = "Dinner"
        default: preferred = "Late Night"
        }

        if let match = periods.first(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
            return match
        }
        // Weekends often serve Brunch in the Lunch window.
        if preferred == "Lunch",
           let brunch = periods.first(where: { $0.localizedCaseInsensitiveContains("brunch") }) {
            return brunch
        }
        return periods.first
    }

    /// Time-of-day greeting on UCI's clock.
    static func greeting() -> String {
        switch UCITime.hour() {
        case ..<4: "Late night, Anteater"
        case ..<12: "Good morning, Anteater"
        case ..<17: "Good afternoon, Anteater"
        default: "Good evening, Anteater"
        }
    }

    /// "2026-07-09" -> "Thursday, Jul 9" (falls back to the raw string).
    private func prettyDate(_ isoDay: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "America/Los_Angeles")
        guard let date = parser.date(from: isoDay) else { return isoDay }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Hall hero card

private struct HallCard: View {
    let hall: DiningLocationID
    let location: DiningLocation?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Color.uciBlue : Color.secondary.opacity(0.6))
                        .symbolEffect(.bounce, value: isSelected)
                    Spacer(minLength: 4)
                    if let location {
                        StatusPill(isOpen: location.openNow)
                    }
                }

                Spacer(minLength: 8)

                Text(hall.displayName)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(isSelected ? Color.uciBlue : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(hall.area)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .bottom, spacing: 6) {
                    if let statusLine {
                        Label(statusLine.text, systemImage: statusLine.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusLine.tint)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    } else if let hours = location?.todayHours {
                        Label(hours, systemImage: "clock")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 4)
                    if let occupancy {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(occupancy.percent)%")
                                .font(.system(size: 16, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(occupancy.tint)
                            Text("typical")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(occupancy.percent) percent full, typical estimate")
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(
                isSelected ? Color.uciBlue.opacity(0.07) : Color.card,
                in: RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.uciBlue.opacity(0.45) : Color.cardBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hall.displayName), \(hall.area)")
        .accessibilityHint("Shows this dining hall's menu")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Nom-style typical occupancy percent, shown only while the hall is serving.
    private var occupancy: (percent: Int, tint: Color)? {
        guard let location, location.openNow, !location.periods.isEmpty else { return nil }
        let estimate = TypicalBusyness.dining(periods: location.periods)
        guard estimate.percentNow > 0 else { return nil }
        return (estimate.percentNow, estimate.levelNow.color)
    }

    /// Live "when" intelligence: what's serving now and when it ends, or what's next.
    private var statusLine: (text: String, icon: String, tint: Color)? {
        guard let location else { return nil }
        let now = UCITime.nowMinutes()
        switch location.openState(nowMinutes: now) {
        case .open(let period, let closesAt):
            return (
                "\(period) · closes in \(UCITime.countdown(from: now, to: closesAt))",
                "clock.badge.checkmark",
                .openGreen
            )
        case .openingLater(let period, let opensAt):
            return (
                "\(period) starts in \(UCITime.countdown(from: now, to: opensAt))",
                "clock.arrow.circlepath",
                .busyOrange
            )
        case .closedForToday:
            return ("Closed for today", "moon.zzz", .secondary)
        case .unknown:
            return nil
        }
    }

}

// MARK: - Dish row card

private struct DishRowCard: View {
    let item: MenuItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(ZotFont.body.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(ZotFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if !item.dietaryTags.isEmpty || !item.allergens.isEmpty {
                        chipRow
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 10) {
                    favoriteButton
                    if let calories = item.calories {
                        CalorieBadge(calories: calories)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .zotCard()
        .overlay(
            RoundedRectangle(cornerRadius: zotCardRadius, style: .continuous)
                .strokeBorder(Color.uciGold.opacity(isFavorite ? 0.65 : 0), lineWidth: 1.5)
        )
        .accessibilityHint("Shows dish details")
    }

    private var chipRow: some View {
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

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.pink : Color.secondary)
                .symbolEffect(.bounce, value: isFavorite)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isFavorite ? "Remove \(item.name) from favorites" : "Add \(item.name) to favorites"
        )
    }
}

// MARK: - Calories badge

private struct CalorieBadge: View {
    let calories: Int

    var body: some View {
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

#Preview {
    DiningView()
}
