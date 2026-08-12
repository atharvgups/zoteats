import SwiftUI
import ZotEatsKit

// The Dining tab — ZotEats' hero surface.
// Hall hero cards -> meal period pills -> dietary filters -> live menu by station.

struct DiningView: View {
    let store: DiningStore
    let prefs: Preferences
    let plate: PlateStore
    @Binding var pendingDeepLink: AnteatsDeepLink?
    @Environment(\.openSettings) private var openSettings

    @State private var selectedHall: String = HallDirectory.fallbackIDs[0]
    @State private var selectedPeriod: String?
    /// Nil means today; otherwise a future ISO date being browsed.
    @State private var selectedDate: String?
    @State private var searchText = ""
    @State private var selectedDish: MenuItem?
    @State private var showDietFilters = false
    @State private var showPlate = false
    /// Eat meal boards: Available-all-day station stays collapsed until tapped.
    @State private var allDayExpanded = false
    @State private var mealActivity = MealActivityManager()
    /// CI screenshot launch args (`-showDishDetail` / `-showPlate`) fire once.
    @State private var didApplyScreenshotArgs = false
    /// Dish name from a notification tap — opened once the menu finishes loading.
    @State private var pendingDishName: String?
    /// Explicit period from Opening Alerts / widgets / Favorite Alerts — hold
    /// Eat snap so an ended Lunch isn't remapped the moment the hall settles.
    @State private var pinnedDeepLinkPeriod: String?
    /// Bumps after each meal-boundary tick so hall chrome / pills re-render.
    @State private var boundaryEpoch = 0
    @Environment(\.scenePhase) private var scenePhase

    /// All published days the feed currently exposes (often a week+ ahead).
    /// Clamped to `/dateRange.latest` so empty 404 days never appear.
    private var upcomingDays: [(isoDate: String, label: String)] {
        let candidates = UCITime.upcomingDays(count: 21)
        guard let latest = store.publishedDateRange?.latest else {
            return Array(candidates.prefix(7))
        }
        let visible = candidates.filter { $0.isoDate <= latest }
        return visible.isEmpty ? Array(candidates.prefix(1)) : visible
    }

    /// Timed windows for the board in view — tomorrow's schedule when browsing ahead.
    private var boardTimedPeriods: [MealPeriodWindow]? {
        guard let date = selectedDate else { return selectedLocation?.periods }
        return store.dayPeriodsState(hall: selectedHall, dateISO: date).value
    }

    /// Period names for pills / snap on the board in view.
    private var boardAvailablePeriods: [String]? {
        guard selectedDate != nil else { return selectedLocation?.availablePeriods }
        return boardTimedPeriods?.map(\.name)
    }

    /// True while a future DayStrip day hasn't finished loading its periods.
    private var browseDayPeriodsPending: Bool {
        guard let date = selectedDate else { return false }
        return store.dayPeriodsState(hall: selectedHall, dateISO: date).value == nil
    }

    private var browsePeriodsTaskID: String {
        "\(selectedHall)|\(selectedDate ?? "today")"
    }

    private var boundaryWatchID: String {
        "\(boundaryEpoch)|\(selectedHall)|\(selectedPeriod ?? "-")|\(selectedDate ?? "today")|\(store.dayEpoch)|\(store.locations.value?.map(\.id).joined() ?? "")"
    }

    var body: some View {
        // Hall cards / Track meal read wall-clock minutes; re-render after ticks.
        let _ = boundaryEpoch
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
            .statusBarBackdrop()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.screen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search today's dishes"
            )
            .refreshable { await refresh() }
            .task {
                await store.loadLocations()
                // Failed feeds leave locations.value nil — still settle pending links.
                applyPendingDeepLinkIfNeeded()
            }
            .task(id: menuTaskID) {
                await loadCurrentMenu()
                considerAutoMealActivity()
                applyScreenshotLaunchArgsIfNeeded()
                openPendingDishIfPossible()
            }
            .task(id: browsePeriodsTaskID) {
                guard let date = selectedDate else { return }
                await store.loadDayPeriods(hall: selectedHall, dateISO: date)
                syncPeriodSelection()
                applyPendingDeepLinkIfNeeded()
            }
            .task(id: boundaryWatchID) {
                await watchMealBoundaries()
            }
            .onChange(of: store.locations.value) {
                syncPeriodSelection()
                considerAutoMealActivity()
                applyPendingDeepLinkIfNeeded()
            }
            .onChange(of: store.publishedDateRange) { syncDateSelection() }
            .onChange(of: selectedHall) {
                // Do not clear pinnedDeepLinkPeriod here — deep-link apply also
                // sets hall, and deferred onChange would wipe the meal pin and
                // snap ended Lunch → Dinner. User hall taps clear the pin.
                allDayExpanded = false
                syncPeriodSelection()
                considerAutoMealActivity()
            }
            .onChange(of: selectedDate) {
                // After-hours Today clears the pill; moving to a future day must
                // snap Breakfast (or first primary) so DayStrip / Menu Drop don't
                // land on "No menu yet" with selectedPeriod == nil.
                // Same as hall: deep links force today / future ISO — don't clear
                // the meal pin from this onChange.
                allDayExpanded = false
                syncPeriodSelection()
            }
            .onChange(of: selectedPeriod) { _, newPeriod in
                allDayExpanded = false
                if let pinned = pinnedDeepLinkPeriod, newPeriod != pinned {
                    pinnedDeepLinkPeriod = nil
                }
            }
            .onChange(of: pendingDeepLink) {
                applyPendingDeepLinkIfNeeded()
            }
            .onAppear {
                syncPeriodSelection()
                syncDateSelection()
                considerAutoMealActivity()
                applyPendingDeepLinkIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                // Overnight warm launch: drop stale Dinner once Irvine is past last meal.
                if phase == .active {
                    syncDateSelection()
                    syncPeriodSelection()
                    considerAutoMealActivity()
                    boundaryEpoch += 1
                }
            }
            .sheet(item: $selectedDish) { dish in
                // Plate CTA only for today — future menus are browse-only.
                DishDetailSheet(
                    dish: dish,
                    prefs: prefs,
                    plate: selectedDate == nil ? plate : nil
                )
            }
            .sheet(isPresented: $showDietFilters) {
                DietFilterSheet(prefs: prefs)
            }
            .sheet(isPresented: $showPlate) {
                PlateSheet(plate: plate)
            }
            // Floating plate tally, only while today's plate has something on it.
            .safeAreaInset(edge: .bottom) {
                if !plate.isEmpty && selectedDate == nil {
                    plateTallyBar
                }
            }
        }
    }

    /// Compact running total pinned above the tab bar; taps open the plate.
    private var plateTallyBar: some View {
        Button {
            showPlate = true
            Haptics.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(plate.entries.count) on your plate")
                    .font(ZotFont.pill.weight(.semibold))
                Spacer()
                Text("\(plate.totalCalories) cal · \(plate.totalProteinG)g protein")
                    .font(ZotFont.pill.weight(.medium))
                    .opacity(0.9)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.uciBlue, in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: Color.uciBlue.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel(
            "My plate: \(plate.entries.count) dishes, \(plate.totalCalories) calories, \(plate.totalProteinG) grams protein"
        )
        .accessibilityIdentifier("plate-tally-bar")
    }

    // MARK: - Derived state

    private var selectedLocation: DiningLocation? {
        store.locations.value?.first { $0.id == selectedHall }
    }

    private var currentMenuState: LoadState<DiningMenu> {
        guard let selectedPeriod else { return .idle }
        return store.menuState(hall: selectedHall, period: selectedPeriod, date: selectedDate)
    }

    /// Drives `.task(id:)` so the menu reloads whenever hall, period, day, or
    /// Irvine day-rollover epoch changes.
    private var menuTaskID: String {
        "\(selectedHall)|\(selectedPeriod ?? "-")|\(selectedDate ?? "today")|\(store.dayEpoch)"
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveFilter: Bool {
        prefs.hasActiveMenuFilters || !trimmedQuery.isEmpty
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
            // Breakfast / Lunch / Dinner only — Brunch and All Day aren't useful pills.
            if let available = boardAvailablePeriods {
                let pills = DiningService.primaryPeriods(from: available)
                if !pills.isEmpty {
                    PillRow(
                        items: pills,
                        title: { $0 },
                        selection: $selectedPeriod,
                        fillsWidth: true
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Meal period")
                }
            }

            HStack(spacing: 10) {
                DayStrip(
                    days: upcomingDays,
                    selection: Binding(
                        get: { selectedDate ?? upcomingDays.first?.isoDate },
                        set: { newValue in
                            let today = upcomingDays.first?.isoDate
                            let next = (newValue == today) ? nil : newValue
                            // User DayStrip tap — drop deep-link meal pin.
                            if next != selectedDate {
                                pinnedDeepLinkPeriod = nil
                            }
                            selectedDate = next
                        }
                    )
                )
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    filterChip
                    if prefs.hasActiveMenuFilters {
                        Button {
                            prefs.clearMenuFilters()
                            Haptics.selection()
                        } label: {
                            Text("Clear")
                                .font(ZotFont.pill.weight(.semibold))
                                .foregroundStyle(Color.uciBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.uciBlue.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("diet-filter-clear")
                        .accessibilityLabel("Clear all filters")
                    }
                }
            }
            .padding(.horizontal, 20)

            menuContent
        }
    }

    /// Compact chip summarizing dietary + allergen filters; opens the picker sheet.
    private var filterChip: some View {
        let diets = prefs.dietFilters.sorted()
        let allergens = prefs.allergenAvoids.sorted()
        let label = MenuFiltersChipAccessibility.title(
            dietFilters: diets,
            allergenAvoids: allergens
        )
        let active = prefs.hasActiveMenuFilters
        return Button {
            showDietFilters = true
            Haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle\(active ? ".fill" : "")")
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(ZotFont.pill.weight(active ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                active ? Color.uciBlue.opacity(0.12) : Color.card,
                in: Capsule()
            )
            .foregroundStyle(active ? Color.uciBlue : Color.primary)
            .overlay(
                Capsule().strokeBorder(
                    active ? Color.uciBlue.opacity(0.35) : Color.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("diet-filter-chip")
        .accessibilityLabel(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: diets,
                allergenAvoids: allergens
            )
        )
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
            // User hall tap — drop deep-link meal pin so snap matches this board.
            pinnedDeepLinkPeriod = nil
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
            switch DiningMenuIdleAction.resolve(
                locationsLoaded: store.locations.value != nil,
                availablePeriods: boardAvailablePeriods,
                selectedPeriod: selectedPeriod,
                browseDayPeriodsPending: browseDayPeriodsPending
            ) {
            case .emptyNoMenu:
                let location = selectedLocation
                let emptyKind = DiningMenuIdleEmptyKind.resolve(
                    browsingToday: selectedDate == nil,
                    openState: location.map { $0.openState(nowMinutes: UCITime.nowMinutes()) }
                )
                let awaiting = emptyKind == .awaitingMoreMeals
                let afterHours = emptyKind == .afterHours
                let emptyBoard = afterHours && (location?.periods.isEmpty ?? false)
                EmptyStateView(
                    icon: awaiting ? "clock.arrow.circlepath" : "moon.zzz",
                    title: TodaysMenuEmptyCopy.eatIdleEmptyTitle(
                        awaitingMoreMeals: awaiting,
                        afterHours: afterHours,
                        emptyBoard: emptyBoard
                    ),
                    message: {
                        switch emptyKind {
                        case .awaitingMoreMeals:
                            return TodaysMenuEmptyCopy.eatAwaitingMoreMealsMessage(
                                hallName: location?.name ?? "This hall"
                            )
                        case .afterHours:
                            return TodaysMenuEmptyCopy.eatAfterHoursMessage(
                                hallName: location?.name ?? "This hall",
                                opensTomorrowPeriod: location?.opensTomorrowPeriod,
                                opensTomorrowAtMinutes: location?.opensTomorrowAtMinutes,
                                opensNextPeriod: location?.opensNextPeriod,
                                opensNextAtMinutes: location?.opensNextAtMinutes,
                                opensNextWeekday: location?.opensNextWeekday,
                                emptyBoard: emptyBoard
                            )
                        case .noMenuPosted:
                            return "\(location?.name ?? "This hall") hasn't posted Breakfast, Lunch, or Dinner for this day. Pull to refresh or check another hall."
                        }
                    }(),
                    actionTitle: {
                        if afterHours {
                            return TodaysMenuEmptyCopy.afterHoursActionTitle(
                                opensTomorrowAtMinutes: location?.opensTomorrowAtMinutes,
                                opensNextWeekday: location?.opensNextWeekday
                            ) ?? "Try Again"
                        }
                        return "Try Again"
                    }()
                ) {
                    if afterHours,
                       let jump = TodaysMenuEmptyCopy.afterHoursJumpISO(
                           opensTomorrowAtMinutes: location?.opensTomorrowAtMinutes,
                           opensNextDateISO: location?.opensNextDateISO,
                           opensNextDayOffset: location?.opensNextDayOffset
                       ) {
                        pinnedDeepLinkPeriod = nil
                        selectedDate = jump
                        Haptics.selection()
                    } else {
                        Task { await refresh() }
                    }
                }
            case .loading:
                loadingPlaceholder
            }
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
                if let copy = EatFilterEmptyCopy.resolve(
                    hasSearch: !trimmedQuery.isEmpty,
                    hasMenuFilters: prefs.hasActiveMenuFilters
                ) {
                    EmptyStateView(
                        icon: "ant",
                        title: copy.title,
                        message: copy.message,
                        actionTitle: copy.actionTitle,
                        retry: {
                            switch copy.action {
                            case .clearSearch:
                                searchText = ""
                            case .clearFilters:
                                prefs.clearMenuFilters()
                            case .clearBoth:
                                prefs.clearMenuFilters()
                                searchText = ""
                            }
                            Haptics.selection()
                        }
                    )
                } else {
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: "No menu posted yet",
                        message: selectedDate == nil
                            ? "\(selectedLocation?.name ?? "This hall") hasn't published \(menu.period.lowercased()) yet. Check back soon."
                            : "UCI hasn't released this day's menu in the dining feed yet. Posted days stay in the date strip — check back as they go live."
                    )
                }
            } else {
                menuList(menu: menu, stations: stations)
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
                .animation(.snappy(duration: 0.25), value: prefs.favoriteDishNames)
            }

            ForEach(stations) { station in
                let isAllDay = CampusMenuNormalize.isAvailableAllDay(station.name)
                VStack(alignment: .leading, spacing: 10) {
                    if isAllDay {
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                allDayExpanded.toggle()
                            }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(Color.uciGold)
                                    .frame(width: 5, height: 21)
                                Text(station.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Text("\(station.items.count)")
                                    .font(ZotFont.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(allDayExpanded ? 180 : 0))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Available all day, \(station.items.count) items")
                        .accessibilityHint(
                            allDayExpanded
                                ? "Hides all-day items"
                                : "Shows all-day items"
                        )

                        if allDayExpanded {
                            ForEach(station.items) { item in
                                dishRow(item)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } else {
                        sectionHeader(title: station.name, count: station.items.count)
                        ForEach(station.items) { item in
                            dishRow(item)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func dishRow(_ item: MenuItem) -> some View {
        DishRowCard(
            item: item,
            isFavorite: prefs.isFavorite(item.name),
            isOnPlate: plate.isOnPlate(item.name),
            onToggleFavorite: { prefs.toggleFavorite(item.name) },
            // Plate building only makes sense for food being served today.
            onTogglePlate: selectedDate == nil
                ? { withAnimation(.snappy(duration: 0.25)) { plate.toggle(item) } }
                : nil,
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
                        let postClose = MealActivityPostClose.destination(
                            currentPeriodEndMinutes: end,
                            timedPeriods: location.periods,
                            opensTomorrowPeriod: location.opensTomorrowPeriod,
                            opensNextPeriod: location.opensNextPeriod,
                            opensNextDayOffset: location.opensNextDayOffset,
                            opensNextDateISO: location.opensNextDateISO
                        )
                        mealActivity.track(
                            hallName: location.name,
                            hallID: location.id,
                            period: menu.period,
                            endsAt: MealTrackMath.endsAt(endMinutes: end, nowMinutes: now),
                            postClosePeriod: postClose.period,
                            postCloseDate: postClose.date,
                            opensTomorrowPeriod: MealActivityPostClose.contentOpensTomorrowPeriod(
                                postClose: postClose,
                                hallOpensTomorrowPeriod: location.opensTomorrowPeriod
                            )
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
        guard prefs.matchesMenuFilters(item) else { return false }
        let query = trimmedQuery
        guard !query.isEmpty else { return true }
        if item.name.localizedCaseInsensitiveContains(query) { return true }
        return item.description?.localizedCaseInsensitiveContains(query) ?? false
    }

    private func filteredStations(_ menu: DiningMenu) -> [MenuStation] {
        // Twisted Root must stay visible under Vegan/Vegetarian even when the
        // Anteater API leaves every diet flag false (common).
        // Owner vegan preference: float Twisted Root to the top of the station list.
        let stations = DiningService.withStationDietOverrides(menu).stations.compactMap { station in
            let items = station.items.filter(matches)
            return items.isEmpty ? nil : MenuStation(name: station.name, items: items)
        }
        let twisted = stations.filter { DiningService.isTwistedRoot(stationName: $0.name) }
        let rest = stations.filter { !DiningService.isTwistedRoot(stationName: $0.name) }
        return twisted + rest
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

    private func loadCurrentMenu(forceRefresh: Bool = false) async {
        // Cache under the primary pill name (Breakfast/Lunch/Dinner). The
        // service resolves Brunch / Limited Dinner internally.
        guard let selectedPeriod else { return }
        await store.loadMenu(
            hall: selectedHall,
            period: selectedPeriod,
            date: selectedDate,
            forceRefresh: forceRefresh
        )
    }

    private func refresh() async {
        // Pull-to-refresh must bypass the 20-minute restaurantToday TTL so a
        // publish that landed minutes ago shows up immediately.
        await store.loadLocations(forceRefresh: true)
        syncPeriodSelection()
        await loadCurrentMenu(forceRefresh: true)
        WidgetReloader.reloadEatWidgets()
        considerAutoMealActivity()
        boundaryEpoch += 1
    }

    /// Sleep until the next meal open/close / any-hall wrap-up / midnight, then
    /// refresh pills, menu, Live Activity, and hall chrome without leaving Eat.
    private func watchMealBoundaries() async {
        guard let locations = store.locations.value, !locations.isEmpty else { return }
        let fire = EatBoundaryRefresh.nextFire(
            hallPeriods: locations.map(\.periods),
            nowMinutes: UCITime.nowMinutes()
        )
        let delay = fire.timeIntervalSinceNow
        if delay > 0.05 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        await applyBoundaryTick()
    }

    private func applyBoundaryTick() async {
        // Midnight (and meal edges / Lunch·Dinner publish probes): purge stale
        // |"today"| menus, clear yesterday's plate, and force-refetch hall
        // windows so an empty or breakfast-only board isn't stuck for 20m.
        plate.ensureCurrentDay()
        store.ensureCurrentDay()
        await store.loadLocations(forceRefresh: true)
        syncDateSelection()
        syncPeriodSelection()
        if selectedDate == nil {
            await loadCurrentMenu(forceRefresh: true)
            considerAutoMealActivity()
        }
        WidgetReloader.reloadEatWidgets()
        boundaryEpoch += 1
    }

    /// When a meal is in its last ~45 minutes, start the Dynamic Island countdown
    /// without requiring a tap (respects Settings → Auto meal countdown).
    /// Picks the soonest-ending hall in wrap-up — not only the selected card —
    /// so Anteatery selected still starts Brandywine when that Lunch ends first.
    private func considerAutoMealActivity() {
        // Tab unload / cold start drop in-memory trackedKey; reconcile first so
        // Tracking stays honest and we don't recreate a live Island timer.
        mealActivity.syncFromSystem()
        guard selectedDate == nil,
              let locations = store.locations.value
        else { return }
        // Board may have grown (Lunch/Dinner publish) since track/auto-start.
        mealActivity.refreshPostCloseIfNeeded(locations: locations)
        guard let pick = MealActivityAutoStart.pick(
                locations: locations,
                nowMinutes: UCITime.nowMinutes(),
                alreadyTracking: mealActivity.trackedKey != nil,
                autoEnabled: MealActivityManager.autoStartEnabled
              )
        else { return }
        let postClose = MealActivityPostClose.destination(
            currentPeriodEndMinutes: pick.endMinutes,
            timedPeriods: pick.timedPeriods,
            opensTomorrowPeriod: pick.opensTomorrowPeriod,
            opensNextPeriod: pick.opensNextPeriod,
            opensNextDayOffset: pick.opensNextDayOffset,
            opensNextDateISO: pick.opensNextDateISO
        )
        mealActivity.autoStartIfNeeded(
            hallName: pick.hallName,
            hallID: pick.hallID,
            period: pick.livePeriodName,
            startMinutes: pick.startMinutes,
            endMinutes: pick.endMinutes,
            postClosePeriod: postClose.period,
            postCloseDate: postClose.date,
            opensTomorrowPeriod: MealActivityPostClose.contentOpensTomorrowPeriod(
                postClose: postClose,
                hallOpensTomorrowPeriod: pick.opensTomorrowPeriod
            )
        )
    }

    /// Notification / widget taps: select hall, period, date; stash dish for after load.
    private func applyPendingDeepLinkIfNeeded() {
        guard let link = pendingDeepLink, link.tab == .eat else { return }
        let needsLocations = link.hall != nil || link.period != nil
        let feedReady: Bool = {
            switch store.locations {
            case .loaded, .failed: return true
            case .idle, .loading: return false
            }
        }()
        switch EatDeepLinkApply.resolve(
            hallID: link.hall,
            needsLocations: needsLocations,
            locations: store.locations.value,
            feedReady: feedReady
        ) {
        case .waitForLocations:
            return
        case .discard:
            pendingDeepLink = nil
            return
        case .apply(let hallID):
            if let hallID {
                selectedHall = hallID
            }
            // Live same-day links omit date — force today so a stuck future
            // DayStrip doesn't keep browsingFutureDay and wrong meal snap.
            let forcesToday = link.hall != nil || link.period != nil || link.dish != nil
            let todayISO = UCITime.upcomingDays(count: 1).first?.isoDate
            switch EatDeepLinkBrowseDay.resolve(
                linkDate: link.date,
                todayISO: todayISO,
                forcesTodayWhenDateOmitted: forcesToday
            ) {
            case .keep:
                break
            case .today:
                selectedDate = nil
            case .future(let iso):
                selectedDate = iso
            }
            // Hall, period, or date taps re-resolve the pill. Bare `anteats://eat`
            // leaves selection alone. Date-only Menu Drop links need a future-day
            // Breakfast snap when today is after hours (pill was cleared).
            // Opening Alerts / Status period taps / Favorite dishes keep the
            // named meal; hall-only links still snap live.
            let preserveMeal = link.period != nil || link.dish != nil
            if link.period != nil || link.hall != nil || link.date != nil {
                // Future-day links wait for that day's periods so weekend Brunch
                // pills don't block weekday Lunch / Breakfast snaps.
                if let date = selectedDate {
                    guard let windows = store.dayPeriodsState(hall: selectedHall, dateISO: date).value
                    else { return }
                    selectedPeriod = EatDeepLinkPeriod.resolve(
                        requested: link.period,
                        availablePeriods: windows.map(\.name),
                        timedPeriods: windows,
                        nowMinutes: UCITime.nowMinutes(),
                        browsingFutureDay: true,
                        preserveRequestedMeal: preserveMeal
                    )
                } else if let location = selectedLocation {
                    selectedPeriod = EatDeepLinkPeriod.resolve(
                        requested: link.period,
                        availablePeriods: location.availablePeriods,
                        timedPeriods: location.periods,
                        nowMinutes: UCITime.nowMinutes(),
                        browsingFutureDay: false,
                        preserveRequestedMeal: preserveMeal
                    )
                }
                pinnedDeepLinkPeriod = EatDeepLinkMealPin.pin(
                    preserveRequestedMeal: preserveMeal,
                    resolvedPeriod: selectedPeriod
                )
            }
            if let dish = link.dish {
                pendingDishName = dish
            }
            pendingDeepLink = nil
            openPendingDishIfPossible()
        }
    }

    private func openPendingDishIfPossible() {
        guard let name = pendingDishName else { return }
        // Wait for the deep-linked meal board — searching a stale live meal
        // clears the pending name before Lunch finishes loading.
        guard selectedPeriod != nil else { return }
        guard case .loaded(let menu) = currentMenuState else { return }
        if let item = menu.stations.flatMap(\.items).first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            selectedDish = item
        } else {
            searchText = name
        }
        pendingDishName = nil
    }

    /// CI helpers: open a labeled dish sheet and/or seed My Plate for screenshots.
    private func applyScreenshotLaunchArgsIfNeeded() {
        guard !didApplyScreenshotArgs else { return }
        let args = ProcessInfo.processInfo.arguments
        let wantDish = args.contains("-showDishDetail")
        let wantPlate = args.contains("-showPlate")
        guard wantDish || wantPlate else { return }

        guard case .loaded(let menu) = currentMenuState else { return }
        let items = menu.stations.flatMap(\.items)
        guard !items.isEmpty else { return }
        didApplyScreenshotArgs = true

        if wantPlate {
            for item in items.prefix(3) where !plate.isOnPlate(item.name) {
                plate.toggle(item)
            }
            if !wantDish {
                showPlate = true
            }
        }

        if wantDish {
            selectedDish = items.first { $0.nutrition?.hasMacros == true } ?? items.first
        }
    }

    /// Keeps the period selection on a primary pill (Breakfast/Lunch/Dinner),
    /// matching Today's Menu after-hours truth (no stale Dinner overnight).
    private func syncPeriodSelection() {
        // Hold an explicit deep-linked meal (Opening Alert / widget / dish) so
        // Eat snap doesn't remap ended Lunch → Dinner under the user.
        if pendingDishName != nil || pinnedDeepLinkPeriod != nil { return }
        guard let available = boardAvailablePeriods,
              let timed = boardTimedPeriods
        else { return }
        selectedPeriod = EatPeriodSelection.snap(
            current: selectedPeriod,
            availablePeriods: available,
            timedPeriods: timed,
            nowMinutes: UCITime.nowMinutes(),
            browsingFutureDay: selectedDate != nil
        )
    }

    /// Snap off days the feed hasn't published yet, and collapse an explicit ISO
    /// that is now Irvine today back to the live board (overnight DayStrip).
    private func syncDateSelection() {
        selectedDate = EatDateSelection.snapLiveToday(
            selectedDateISO: selectedDate,
            todayISO: UCITime.todayISO()
        )
        let days = upcomingDays
        guard let selectedDate else { return }
        if days.contains(where: { $0.isoDate == selectedDate }) { return }
        self.selectedDate = nil
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
        HStack(spacing: 0) {
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
            if days.count > 3 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Menu day, swipe for more days")
    }
}

// MARK: - Dietary + allergen filter sheet

/// Compact multi-select sheet — keeps Eat uncluttered vs a permanent pill row.
/// Diet filters combine as AND; allergen avoids hide dishes that list them.
struct DietFilterSheet: View {
    let prefs: Preferences
    @Environment(\.dismiss) private var dismiss

    private static let dietOptions = ["Vegan", "Vegetarian", "Halal", "Kosher", "Gluten-Free"]
    private static let allergenOptions = [
        "Eggs", "Fish", "Milk", "Peanuts", "Sesame", "Shellfish", "Soy", "Tree Nuts", "Wheat",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Filters")
                    .font(ZotFont.hero(24))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(ZotFont.pill.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.uciBlue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("diet-filter-done")
            }
            .padding(.bottom, 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Diet — dishes must match all selected.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)

                    ForEach(Self.dietOptions, id: \.self) { option in
                        filterRow(
                            title: option,
                            subtitle: "Only \(option.lowercased()) dishes",
                            color: TagPalette.dietColor(option),
                            isSelected: prefs.dietFilters.contains(option)
                        ) {
                            if prefs.dietFilters.contains(option) {
                                prefs.dietFilters.remove(option)
                            } else {
                                prefs.dietFilters.insert(option)
                            }
                        }
                    }

                    Text("Avoid allergens — hides dishes that list them.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    Text("Only works when UCI publishes allergen data for that dish.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)

                    ForEach(Self.allergenOptions, id: \.self) { option in
                        filterRow(
                            title: option,
                            subtitle: "Hide dishes with \(option.lowercased())",
                            color: TagPalette.allergenColor,
                            isSelected: prefs.allergenAvoids.contains(option)
                        ) {
                            if prefs.allergenAvoids.contains(option) {
                                prefs.allergenAvoids.remove(option)
                            } else {
                                prefs.allergenAvoids.insert(option)
                            }
                        }
                    }

                    if prefs.hasActiveMenuFilters {
                        Button {
                            prefs.clearMenuFilters()
                            Haptics.selection()
                        } label: {
                            Text("Clear all")
                                .font(ZotFont.pill.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .accessibilityIdentifier("diet-filter-clear")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(Color.screen)
        .animation(.snappy(duration: 0.2), value: prefs.dietFilters)
        .animation(.snappy(duration: 0.2), value: prefs.allergenAvoids)
    }

    private func filterRow(
        title: String,
        subtitle: String,
        color: Color,
        isSelected: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button {
            toggle()
            Haptics.selection()
        } label: {
            HStack {
                TagChip(text: title, color: color)
                Text(subtitle)
                    .font(ZotFont.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.uciBlue : Color.secondary.opacity(0.4))
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
        .accessibilityLabel(DietFilterRowAccessibility.label(title: title, subtitle: subtitle))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(DietFilterRowAccessibility.hint(isSelected: isSelected))
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
                    } else {
                        // Empty board before Lunch probe (`.unknown`) — hoursLine
                        // says "Menu not posted yet"; never echo stale todayHours.
                        Text(location.hoursLine())
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
                        .accessibilityHidden(true)
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
            DiningHallCardAccessibilityLabel.label(
                name: location.name,
                isOpen: location.isServing(nowMinutes: UCITime.nowMinutes()),
                statusLine: statusLine?.text,
                occupancyPercent: occupancy?.percent
            )
        )
        .accessibilityHint("Shows this dining hall's menu")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Nom-style typical occupancy percent, shown only while the hall is serving.
    private var occupancy: (percent: Int, tint: Color)? {
        let now = UCITime.nowMinutes()
        guard location.isServing(nowMinutes: now), !location.periods.isEmpty else { return nil }
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
        case .awaitingMoreMeals:
            return ("More meals post later", "clock.badge.questionmark", .busyOrange)
        case .closedForToday:
            if let open = location.opensTomorrowAtMinutes {
                let meal = location.opensTomorrowPeriod ?? "Opens"
                return (
                    "\(meal) tomorrow · \(UCITime.format(minutes: open))",
                    "moon.zzz",
                    .secondary
                )
            }
            if let open = location.opensNextAtMinutes,
               let weekday = location.opensNextWeekday,
               !weekday.isEmpty {
                let meal = location.opensNextPeriod ?? "Opens"
                return (
                    "\(meal) \(weekday) · \(UCITime.format(minutes: open))",
                    "moon.zzz",
                    .secondary
                )
            }
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
    var isOnPlate: Bool = false
    let onToggleFavorite: () -> Void
    var onTogglePlate: (() -> Void)?
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
                    HStack(spacing: 8) {
                        if let onTogglePlate {
                            plateButton(onTogglePlate)
                        }
                        favoriteButton
                    }
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
        .accessibilityLabel(
            DishRowAccessibility.label(
                dishName: item.name,
                calories: item.calories,
                dietaryTags: item.dietaryTags,
                allergens: item.allergens
            )
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

    private func plateButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isOnPlate ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOnPlate ? Color.uciBlue : Color.uciBlue.opacity(0.85))
                .symbolEffect(.bounce, value: isOnPlate)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isOnPlate ? "Remove \(item.name) from my plate" : "Add \(item.name) to my plate"
        )
        .accessibilityIdentifier("plate-toggle")
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
    DiningView(
        store: DiningStore(),
        prefs: Preferences(),
        plate: PlateStore(),
        pendingDeepLink: .constant(nil)
    )
}
