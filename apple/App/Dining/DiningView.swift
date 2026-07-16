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
    @State private var showDietFilters = false
    @State private var mealActivity = MealActivityManager()

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
            // Warm the selected hall's other periods so switching is instant.
            .task(id: "prefetch|\(selectedHall)|\(store.locations.value != nil)") {
                if let location = selectedLocation {
                    await store.prefetchMenus(hall: location.id, periods: location.availablePeriods)
                }
            }
            .onChange(of: store.locations.value) { syncPeriodSelection() }
            .onChange(of: selectedHall) { syncPeriodSelection() }
            .sheet(item: $selectedDish) { dish in
                DishDetailSheet(dish: dish, prefs: prefs)
            }
            .sheet(isPresented: $showDietFilters) {
                DietFilterSheet(prefs: prefs)
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
            // One primary control row (meal periods), then a single quiet row
            // combining the day strip and a filter chip — down from three
            // stacked pill rows.
            if let location = selectedLocation, !location.availablePeriods.isEmpty {
                PillRow(
                    items: location.availablePeriods,
                    title: { $0 },
                    selection: $selectedPeriod
                )
                .accessibilityLabel("Meal period")
            }

            HStack(spacing: 10) {
                DayStrip(
                    days: upcomingDays,
                    selection: Binding(
                        get: { selectedDate ?? upcomingDays.first?.isoDate },
                        set: { newValue in
                            let today = upcomingDays.first?.isoDate
                            selectedDate = (newValue == today) ? nil : newValue
                        }
                    )
                )
                Spacer(minLength: 8)
                filterChip
            }
            .padding(.horizontal, 20)

            menuContent
        }
    }

    /// Compact chip summarizing the dietary filter; opens the picker sheet.
    private var filterChip: some View {
        let active = prefs.dietFilter
        return Button {
            showDietFilters = true
            Haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle\(active != nil ? ".fill" : "")")
                    .font(.system(size: 14, weight: .semibold))
                Text(active ?? "Filters")
                    .font(ZotFont.pill.weight(active != nil ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                active != nil ? Color.uciBlue.opacity(0.12) : Color.card,
                in: Capsule()
            )
            .foregroundStyle(active != nil ? Color.uciBlue : .primary)
            .overlay(
                Capsule().strokeBorder(
                    active != nil ? Color.uciBlue.opacity(0.35) : Color.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("diet-filter-chip")
        .accessibilityLabel(active.map { "Dietary filter: \($0)" } ?? "Dietary filters")
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
                    .onAppear {
                        PerfMetrics.markFirstContent("eat", cached: true)
                    }
            }
        }
    }

    private func menuList(menu: DiningMenu, stations: [MenuStation]) -> some View {
        // Generous spacing between stations welds each header to its own
        // section instead of floating between two.
        LazyVStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 8) {
                Text("\(menu.period) • \(prettyDate(menu.date))")
                    .font(ZotFont.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                trackMealButton(menu: menu)
            }
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

    /// Live Activity control: only for today's currently-serving meal.
    @ViewBuilder
    private func trackMealButton(menu: DiningMenu) -> some View {
        if selectedDate == nil,
           let location = selectedLocation,
           mealActivity.isAvailable,
           let window = location.periods.first(where: {
               $0.name.caseInsensitiveCompare(menu.period) == .orderedSame
           }),
           let end = window.endMinutes,
           let start = window.startMinutes {
            let now = UCITime.nowMinutes()
            if now >= start && now < end {
                let tracking = mealActivity.isTracking(hall: location.id, period: menu.period)
                Button {
                    if tracking {
                        mealActivity.endAll()
                    } else {
                        let secondsLeft = TimeInterval((end - now) * 60)
                        mealActivity.track(
                            hallName: location.name,
                            hallID: location.id,
                            period: menu.period,
                            endsAt: Date(timeIntervalSinceNow: secondsLeft)
                        )
                    }
                    Haptics.selection()
                } label: {
                    Label(
                        tracking ? "Tracking" : "Track meal",
                        systemImage: tracking ? "timer.circle.fill" : "timer"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        tracking ? Color.uciBlue.opacity(0.12) : Color.card,
                        in: Capsule()
                    )
                    .foregroundStyle(tracking ? Color.uciBlue : .secondary)
                    .overlay(
                        Capsule().strokeBorder(
                            tracking ? Color.uciBlue.opacity(0.35) : Color.cardBorder,
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    tracking
                        ? "Stop tracking \(menu.period)"
                        : "Track \(menu.period) — live countdown on your lock screen"
                )
            }
        }
    }

    private func sectionHeader(
        title: String,
        count: Int,
        icon: String? = nil,
        tint: Color = .uciGold
    ) -> some View {
        HStack(spacing: 9) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(tint)
                    .frame(width: 5, height: 21)
            }
            // A full step above dish names so station boundaries scan clearly.
            Text(title)
                .font(.system(size: 20, weight: .bold))
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

    /// The meal that matters right now: the one being served, else the next
    /// one starting today, else the day's last meal (evenings after close),
    /// else whatever's first.
    private func defaultPeriod(for location: DiningLocation) -> String? {
        guard !location.availablePeriods.isEmpty else { return nil }
        let now = UCITime.nowMinutes()
        let timed = location.periods.filter { $0.startMinutes != nil && $0.endMinutes != nil }

        if let current = timed.first(where: { now >= $0.startMinutes! && now < $0.endMinutes! }) {
            return current.name
        }
        if let upcoming = timed
            .filter({ $0.startMinutes! > now })
            .min(by: { $0.startMinutes! < $1.startMinutes! }) {
            return upcoming.name
        }
        if let last = timed.max(by: { $0.endMinutes! < $1.endMinutes! }) {
            return last.name
        }
        return location.availablePeriods.first
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

// MARK: - Compact day strip

/// Quiet text-button day selector — visually lighter than a pill row so the
/// meal periods stay the primary control.
private struct DayStrip: View {
    let days: [(isoDate: String, label: String)]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(days, id: \.isoDate) { day in
                    let isSelected = selection == day.isoDate
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            selection = day.isoDate
                        }
                        Haptics.selection()
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.label)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.uciBlue : .secondary)
                            Capsule()
                                .fill(isSelected ? Color.uciBlue : .clear)
                                .frame(height: 3)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Menu for \(day.label)")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Menu day")
    }
}

// MARK: - Dietary filter sheet

/// One tidy sheet instead of a permanent pill row on the main screen.
struct DietFilterSheet: View {
    let prefs: Preferences
    @Environment(\.dismiss) private var dismiss

    private static let options = ["Vegan", "Vegetarian", "Halal", "Kosher", "Gluten-Free"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dietary filter")
                .font(ZotFont.hero(24))
                .padding(.bottom, 10)

            ForEach(Self.options, id: \.self) { option in
                let isSelected = prefs.dietFilter == option
                Button {
                    prefs.dietFilter = isSelected ? nil : option
                    Haptics.selection()
                    dismiss()
                } label: {
                    HStack {
                        TagChip(text: option, color: TagPalette.dietColor(option))
                        Text("Only show \(option.lowercased()) dishes")
                            .font(ZotFont.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.uciBlue)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        isSelected ? Color.uciBlue.opacity(0.08) : Color.card,
                        in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.uciBlue.opacity(0.35) : Color.cardBorder,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option) filter\(isSelected ? ", active" : "")")
            }

            if prefs.dietFilter != nil {
                Button {
                    prefs.dietFilter = nil
                    Haptics.selection()
                    dismiss()
                } label: {
                    Text("Clear filter")
                        .font(ZotFont.pill.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(Color.screen)
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
                    if FeatureFlags.diningHallOccupancy, let occupancy {
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
            // Fixed height keeps the two hall cards identical regardless of
            // how long each status line runs.
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 82, alignment: .top)
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

    /// Live "when" intelligence. Countdowns read best when the moment is close;
    /// beyond 90 minutes a clock time ("until 2:00 PM") is clearer than math.
    private var statusLine: (text: String, icon: String, tint: Color)? {
        let now = UCITime.nowMinutes()
        switch location.openState(nowMinutes: now) {
        case .open(let period, let closesAt):
            let text = closesAt - now <= 90
                ? "\(period) · closes in \(UCITime.countdown(from: now, to: closesAt))"
                : "\(period) · until \(UCITime.format(minutes: closesAt % (24 * 60)))"
            return (text, "clock.badge.checkmark", .openGreen)
        case .openingLater(let period, let opensAt):
            let text = opensAt - now <= 90
                ? "\(period) starts in \(UCITime.countdown(from: now, to: opensAt))"
                : "\(period) at \(UCITime.format(minutes: opensAt))"
            return (text, "clock.arrow.circlepath", .busyOrange)
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
