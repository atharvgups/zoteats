import SwiftUI
import ZotEatsKit

// The Dining tab — ZotEats' hero surface.
// Hall hero cards -> meal period pills -> dietary filters -> live menu by station.

struct DiningView: View {
    let store: DiningStore
    let prefs: Preferences
    @Environment(\.openSettings) private var openSettings

    @State private var selectedHall: String = HallDirectory.fallbackIDs[0]
    @State private var selectedPeriod: String?
    /// Nil means today; otherwise a future ISO date being browsed.
    @State private var selectedDate: String?
    @State private var searchText = ""
    @State private var selectedDish: MenuItem?

    /// Today + the next few days (menus are usually published a few days out).
    private let upcomingDays = UCITime.upcomingDays(count: 5)

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
        return store.menuState(hall: selectedHall, period: selectedPeriod, date: selectedDate)
    }

    /// Drives `.task(id:)` so the menu reloads whenever hall, period, or day changes.
    private var menuTaskID: String {
        "\(selectedHall)|\(selectedPeriod ?? "-")|\(selectedDate ?? "today")"
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
        // Environment @Observable objects need @Bindable for $ bindings.
        @Bindable var prefs = prefs
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
            // Day selector: browse the next few days' menus.
            PillRow(
                items: upcomingDays.map(\.isoDate),
                title: { iso in upcomingDays.first { $0.isoDate == iso }?.label ?? iso },
                selection: Binding(
                    get: { selectedDate ?? upcomingDays.first?.isoDate },
                    set: { newValue in
                        let today = upcomingDays.first?.isoDate
                        selectedDate = (newValue == today) ? nil : newValue
                    }
                )
            )
            .accessibilityLabel("Menu day")

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

    /// Hall cards straight from the live API — a third commons appears here
    /// automatically. Two halls share the width; more become a scrollable row.
    @ViewBuilder
    private var hallSelector: some View {
        let locations = store.locations.value
        if let locations, locations.count > 2 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(locations) { location in
                        hallCard(for: location)
                            .frame(width: 172)
                    }
                }
            }
        } else {
            HStack(spacing: 12) {
                if let locations, !locations.isEmpty {
                    ForEach(locations) { location in
                        hallCard(for: location)
                    }
                } else {
                    SkeletonCard(height: 88)
                    SkeletonCard(height: 88)
                }
            }
        }
    }

    private func hallCard(for location: DiningLocation) -> some View {
        HallCard(
            location: location,
            isSelected: location.id == selectedHall
        ) {
            guard location.id != selectedHall else { return }
            withAnimation(.snappy(duration: 0.3)) {
                selectedHall = location.id
            }
            Haptics.selection()
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
                        icon: "ant",
                        title: "Nothing matches that filter",
                        message: "The anteaters got to it first. Try a different search or clear your dietary filter."
                    )
                } else {
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: "No menu posted",
                        message: selectedDate == nil
                            ? "\(selectedLocation?.name ?? "This hall") hasn't published \(menu.period.lowercased()) yet. Check back soon."
                            : "\(selectedLocation?.name ?? "This hall") hasn't posted that day's \(menu.period.lowercased()) yet — menus usually appear a few days ahead."
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
        await store.loadMenu(hall: selectedHall, period: selectedPeriod, date: selectedDate)
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
    let location: DiningLocation
    let isSelected: Bool
    let onSelect: () -> Void

    // Deliberately minimal: name + open state, then one "when" line and the
    // occupancy number. No icons, no location subtitle — just what decides
    // "which hall do I go to".
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // No status pill: the countdown line below already reads
                // open/closed in words and color, and the name needs the width.
                Text(location.name)
                    .font(ZotFont.cardTitle)
                    .foregroundStyle(isSelected ? Color.uciBlue : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(alignment: .bottom, spacing: 6) {
                    if let statusLine {
                        Text(statusLine.text)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(statusLine.tint)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    } else if let hours = location.todayHours {
                        Text(hours)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 4)
                    if let occupancy {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(occupancy.percent)%")
                                .font(.system(size: 16, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(occupancy.tint)
                            Text("occupancy")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(occupancy.percent) percent occupancy, typical estimate")
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(
            "\(location.name), \(location.area), \(location.openNow ? "open" : "closed")"
        )
        .accessibilityHint("Shows this dining hall's menu")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Nom-style typical occupancy percent, shown only while the hall is serving.
    private var occupancy: (percent: Int, tint: Color)? {
        guard location.openNow, !location.periods.isEmpty else { return nil }
        let estimate = TypicalBusyness.dining(periods: location.periods)
        guard estimate.percentNow > 0 else { return nil }
        return (estimate.percentNow, estimate.levelNow.color)
    }

    /// Live "when" intelligence: what's serving now and when it ends, or what's next.
    private var statusLine: (text: String, icon: String, tint: Color)? {
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
        .background(Color.uciBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous))
        .accessibilityLabel("\(calories) calories")
    }
}

#Preview {
    DiningView(store: DiningStore(), prefs: Preferences())
}
