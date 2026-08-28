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

    /// Today plus future days that actually have a posted board for this hall.
    /// `/dateRange` is a window — Tue/Wed can be empty while Thursday is live.
    private var upcomingDays: [EatPostedDay] {
        let today = UCITime.todayISO()
        let candidates = UCITime.upcomingDays(count: 21)
        return EatPostedDays.visible(
            candidates: candidates,
            todayISO: today,
            postedISOs: store.postedMenuDates[selectedHall]
        )
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
        // Flat ScrollView (no searchable / empty nav bar) so Eat title sits under
        // the status bar like Campus — Atharv: kill search + top inset gap.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Eat", subtitle: Self.greeting(), onSettings: openSettings)

                hallSelector
                    .padding(.horizontal, 20)

                content
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .statusBarBackdrop()
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
        // Plate access: full tally on today when filled; quiet chip otherwise;
        // browse-ahead keeps today's plate visible without implying add works.
        .safeAreaInset(edge: .bottom) {
            if selectedDate == nil {
                if plate.isEmpty {
                    EmptyView()
                } else {
                    plateTallyBar
                }
            } else if !plate.isEmpty {
                browseAheadPlateBar
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
                Text(PlateTallyCopy.barTitle(count: plate.entries.count))
                    .font(ZotFont.pill.weight(.semibold))
                Spacer()
                Text("\(plate.totalCalories) cal · \(plate.totalProteinG)g protein")
                    .font(ZotFont.pill.weight(.medium))
                    .opacity(0.9)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.ink, in: Capsule())
            .foregroundStyle(Color.screen)
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

    /// While browsing tomorrow+, keep today's plate one tap away.
    private var browseAheadPlateBar: some View {
        Button {
            showPlate = true
            Haptics.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(PlateTallyCopy.browseAheadTitle(count: plate.entries.count))
                    .font(ZotFont.pill.weight(.semibold))
                Spacer()
                Text("View")
                    .font(ZotFont.pill.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.ink.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.ink)
            .overlay(Capsule().strokeBorder(Color.ink.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel(
            "Today's plate: \(plate.entries.count) dishes. Opens My Plate."
        )
        .accessibilityIdentifier("plate-browse-ahead-bar")
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
            if selectedLocation?.isComingSoon == true {
                comingSoonHallEmpty
            } else {
                // Always show Breakfast / Lunch / Dinner — never hide unposted meals.
                // (Breakfast-only boards used to render a giant single pill.)
                PillRow(
                    items: DiningService.mealSelectorPills,
                    title: { $0 },
                    selection: $selectedPeriod,
                    fillsWidth: true
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Meal period")
                .accessibilityHint("Peek Lunch or Dinner even before that meal is posted")

                // Dates + Plate + Filters on one row — actions stay fixedSize so
                // they never truncate to "My…" / "Fil…" while dates scroll.
                HStack(alignment: .center, spacing: 8) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if plate.isEmpty {
                            myPlateChip
                        }
                        filterChip
                        if prefs.hasActiveMenuFilters {
                            Button {
                                prefs.clearMenuFilters()
                                Haptics.selection()
                            } label: {
                                Text("Clear")
                                    .font(ZotFont.pill.weight(.semibold))
                                    .foregroundStyle(Color.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.ink.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("diet-filter-clear")
                            .accessibilityLabel("Clear all filters")
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }
                .padding(.horizontal, 20)

                menuContent
            }
        }
    }

    /// Honest Oasis / future-hall card — Hub facts only, no invented menu.
    private var comingSoonHallEmpty: some View {
        let name = selectedLocation?.name ?? "This hall"
        return EmptyStateView(
            icon: "building.2",
            title: "\(name) · Coming Soon",
            message: "Opens Sept 21 · Lunch & Dinner"
        )
    }

    /// Compact inline chip — idle like Filters; blue only while the plate sheet is open.
    private var myPlateChip: some View {
        let active = showPlate
        return Button {
            showPlate = true
            Haptics.selection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text("Plate")
                    .font(ZotFont.pill.weight(active ? .semibold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                active ? Color.ink.opacity(0.12) : Color.card,
                in: Capsule()
            )
            .foregroundStyle(active ? Color.ink : Color.primary)
            .overlay(
                Capsule().strokeBorder(
                    active ? Color.ink.opacity(0.35) : Color.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .help(PlateTallyCopy.chipTitle(count: plate.entries.count))
        .accessibilityIdentifier("my-plate-chip")
        .accessibilityLabel("My Plate, empty")
    }

    /// Inline Filters chip — always says "Filters" (details in VoiceOver / help).
    private var filterChip: some View {
        let diets = prefs.dietFilters.sorted()
        let allergens = prefs.allergenAvoids.sorted()
        let active = prefs.hasActiveMenuFilters
        return Button {
            showDietFilters = true
            Haptics.selection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle\(active ? ".fill" : "")")
                    .font(.system(size: 13, weight: .semibold))
                Text("Filters")
                    .font(ZotFont.pill.weight(active ? .semibold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                active ? Color.ink.opacity(0.12) : Color.card,
                in: Capsule()
            )
            .foregroundStyle(active ? Color.ink : Color.primary)
            .overlay(
                Capsule().strokeBorder(
                    active ? Color.ink.opacity(0.35) : Color.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .help(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: diets,
                allergenAvoids: allergens
            )
        )
        .accessibilityIdentifier("diet-filter-chip")
        .accessibilityLabel(
            MenuFiltersChipAccessibility.accessibilityLabel(
                dietFilters: diets,
                allergenAvoids: allergens
            )
        )
    }

    /// Live halls as two wide buttons (actually bigger). Coming Soon (Oasis)
    /// sits as a short full-width strip so the row isn’t three tall skinny cards.
    @ViewBuilder
    private var hallSelector: some View {
        let locations = store.locations.value
        let live = (locations ?? []).filter { !$0.isComingSoon }
        let soon = (locations ?? []).filter(\.isComingSoon)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if live.isEmpty, locations == nil {
                    SkeletonCard(height: 88)
                    SkeletonCard(height: 88)
                } else {
                    ForEach(live) { location in
                        hallCard(for: location, compact: false)
                    }
                }
            }
            ForEach(soon) { location in
                hallCard(for: location, compact: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dining hall")
    }

    private func hallCard(for location: DiningLocation, compact: Bool) -> some View {
        let isSelected = location.id == selectedHall
        let status = HallChromeStatus.resolve(for: location)
        return Button {
            guard location.id != selectedHall else { return }
            pinnedDeepLinkPeriod = nil
            withAnimation(ZotMotion.select) {
                selectedHall = location.id
            }
            Haptics.selection()
        } label: {
            Group {
                if compact {
                    HStack(spacing: 10) {
                        Text(HallDirectory.compactName(for: location.id))
                            .font(ZotFont.face(16, relativeTo: .headline).weight(.medium))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(status.text)
                            .font(ZotFont.face(13, relativeTo: .caption).weight(.medium))
                            .foregroundStyle(status.tint)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(HallDirectory.compactName(for: location.id))
                            .font(ZotFont.face(21, relativeTo: .title3))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(status.text)
                            .font(ZotFont.caption)
                            .foregroundStyle(status.tint)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.selectWash : Color.card,
                in: RoundedRectangle(cornerRadius: zotHallRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: zotHallRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.ink.opacity(0.28) : Color.cardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            DiningHallCardAccessibilityLabel.label(
                name: location.name,
                isOpen: location.isServing(nowMinutes: UCITime.nowMinutes()),
                statusLine: status.text,
                occupancyPercent: nil
            )
        )
        .accessibilityHint("Shows this dining hall's menu")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: "No menu posted yet",
                        message: selectedDate == nil
                            ? EatBrowseEmptyCopy.message(
                                period: menu.period,
                                browsingFutureDay: false
                            )
                            : EatBrowseEmptyCopy.message(
                                period: menu.period,
                                browsingFutureDay: true
                            )
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
        LazyVStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 8) {
                Text(
                    EatPostedDays.browseCaption(
                        period: menu.period,
                        prettyDate: prettyDate(menu.date),
                        skipsAhead: upcomingDays.contains { $0.isoDate == menu.date && $0.skipsAhead }
                    )
                )
                    .font(ZotFont.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                trackMealButton(menu: menu)
            }
            .padding(.horizontal, 20)

            let favorites = favoriteItems(in: stations)
            let hits = hitItems(in: stations)
            if !favorites.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        title: "Favorites today",
                        count: favorites.count,
                        icon: "heart.fill",
                        tint: .accent
                    )
                    groupedDishes(favorites)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
                .animation(.snappy(duration: 0.25), value: prefs.favoriteDishNames)
            }

            if !hits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        title: "Hits",
                        count: hits.count,
                        icon: "star.fill",
                        tint: .accent
                    )
                    groupedDishes(hits)
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
                .animation(.snappy(duration: 0.25), value: prefs.mealReviews)
            }

            ForEach(stations) { station in
                let isAllDay = CampusMenuNormalize.isAvailableAllDay(station.name)
                VStack(alignment: .leading, spacing: 12) {
                    if isAllDay {
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                allDayExpanded.toggle()
                            }
                            Haptics.selection()
                        } label: {
                            sectionHeader(
                                title: station.name,
                                count: station.items.count,
                                chevron: allDayExpanded ? "chevron.up" : "chevron.down"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Available all day, \(station.items.count) items")
                        .accessibilityHint(
                            allDayExpanded
                                ? "Hides all-day items"
                                : "Shows all-day items"
                        )

                        if allDayExpanded {
                            groupedDishes(station.items)
                                .transition(.opacity)
                        }
                    } else {
                        sectionHeader(title: station.name, count: station.items.count)
                        groupedDishes(station.items)
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
            stars: prefs.review(for: item.name)?.stars ?? 0,
            onToggleFavorite: { prefs.toggleFavorite(item.name) },
            // Plate building only makes sense for food being served today.
            onTogglePlate: selectedDate == nil
                ? { withAnimation(.snappy(duration: 0.25)) { plate.toggle(item) } }
                : nil,
            onRate: { stars in
                prefs.setReview(
                    dishName: item.name,
                    stars: stars,
                    note: prefs.review(for: item.name)?.note ?? ""
                )
            },
            onOpen: { selectedDish = item }
        )
        .accessibilityIdentifier("dish-row")
    }

    /// Live Activity control: only for today's currently-serving meal.
    @ViewBuilder
    private func trackMealButton(menu: DiningMenu) -> some View {
        if selectedDate == nil,
           let location = selectedLocation,
           let window = location.periods.first(where: {
               $0.name.caseInsensitiveCompare(menu.period) == .orderedSame
           }),
           let end = window.endMinutes,
           let start = window.startMinutes {
            let now = UCITime.nowMinutes()
            if now >= start && now < end {
                if mealActivity.isAvailable {
                    let tracking = mealActivity.isTracking(hall: location.id, period: menu.period)
                    Button {
                        Task {
                            if tracking {
                                await mealActivity.endAll()
                                Haptics.selection()
                            } else {
                                let postClose = MealActivityPostClose.destination(
                                    currentPeriodEndMinutes: end,
                                    timedPeriods: location.periods,
                                    opensTomorrowPeriod: location.opensTomorrowPeriod,
                                    opensNextPeriod: location.opensNextPeriod,
                                    opensNextDayOffset: location.opensNextDayOffset,
                                    opensNextDateISO: location.opensNextDateISO
                                )
                                _ = await mealActivity.track(
                                    hallName: location.name,
                                    hallID: location.id,
                                    period: menu.period,
                                    endsAt: MealTrackMath.endsAt(endMinutes: end, nowMinutes: now),
                                    postClosePeriod: postClose.period,
                                    postCloseDate: postClose.date,
                                    opensTomorrowPeriod: MealActivityPostClose
                                        .contentOpensTomorrowPeriod(
                                            postClose: postClose,
                                            hallOpensTomorrowPeriod: location.opensTomorrowPeriod
                                        )
                                )
                            }
                        }
                    } label: {
                        Label(
                            tracking ? "Tracking" : "Track meal",
                            systemImage: tracking ? "timer.circle.fill" : "timer"
                        )
                        .font(ZotFont.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            tracking ? Color.ink.opacity(0.12) : Color.card,
                            in: Capsule()
                        )
                        .foregroundStyle(tracking ? Color.ink : .secondary)
                        .overlay(
                            Capsule().strokeBorder(
                                tracking ? Color.ink.opacity(0.35) : Color.cardBorder,
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
                } else {
                    // Honest affordance — don't hide Track when the meal is live
                    // but system Live Activities are off.
                    Label("Live Activities off", systemImage: "timer")
                        .font(ZotFont.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.card, in: Capsule())
                        .foregroundStyle(.tertiary)
                        .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
                        .accessibilityLabel(
                            "Live Activities are off — enable them in iOS Settings to track \(menu.period)"
                        )
                }
            }
        }
    }

    private func groupedDishes(_ items: [MenuItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                dishRow(item)
                if index < items.count - 1 {
                    ZotHairline(leading: 16)
                }
            }
        }
        .zotCard()
    }

    private func sectionHeader(
        title: String,
        count: Int,
        icon: String? = nil,
        tint: Color = Color.accent,
        chevron: String? = nil
    ) -> some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(tint)
                    .frame(width: 3, height: 14)
            }
            Text(title)
                .font(ZotFont.sectionTitle)
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Text("\(count)")
                .font(ZotFont.caption)
                .foregroundStyle(Color.inkMuted)
                .monospacedDigit()
                .accessibilityLabel("\(count) dishes")
            if let chevron {
                Image(systemName: chevron)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, height: 18)
            }
        }
        .contentShape(Rectangle())
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
        prefs.matchesMenuFilters(item)
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

    /// 4–5 star dishes on this board — glance strip, like Nom’s popular picks.
    private func hitItems(in stations: [MenuStation]) -> [MenuItem] {
        var seen = Set<String>()
        var result: [MenuItem] = []
        for station in stations {
            for item in station.items {
                guard let stars = prefs.review(for: item.name)?.stars,
                      MealReviewLogic.isHit(stars),
                      seen.insert(item.name.lowercased()).inserted
                else { continue }
                result.append(item)
            }
        }
        return result.sorted { lhs, rhs in
            let left = prefs.review(for: lhs.name)?.stars ?? 0
            let right = prefs.review(for: rhs.name)?.stars ?? 0
            if left != right { return left > right }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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
        // Warm sibling hall boards for Favorites Today (today only).
        if selectedDate == nil {
            await store.warmWidgetMenusForLiveHalls(
                preferredHall: selectedHall,
                preferredPeriod: selectedPeriod
            )
        }
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
        Task {
            await mealActivity.autoStartIfNeeded(
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
        case ..<4: "Still hungry, Anteater?"
        case ..<12: "What’s for breakfast?"
        case ..<17: "What’s on the board?"
        default: "Dinner plans, Anteater?"
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
    let days: [EatPostedDay]
    @Binding var selection: String?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.element.isoDate) { index, day in
                        if index > 0,
                           EatPostedDays.skipsCalendarDays(
                            from: days[index - 1].isoDate,
                            to: day.isoDate
                           ) {
                            Text("···")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        let isSelected = selection == day.isoDate
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selection = day.isoDate
                            }
                            Haptics.selection()
                        } label: {
                            VStack(spacing: 2) {
                                Text(day.label)
                                    .font(ZotFont.face(13, relativeTo: .caption).weight(isSelected ? .medium : .regular))
                                    .foregroundStyle(isSelected ? Color.ink : .secondary)
                                Capsule()
                                    .fill(isSelected ? Color.ink : .clear)
                                    .frame(height: 2.5)
                            }
                            .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.accessibilityLabel)
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
        .accessibilityLabel(
            days.contains(where: \.skipsAhead)
                ? "Days with a menu. Next board skips days that aren’t posted yet."
                : "Days with a menu"
        )
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
                        .background(Color.ink, in: Capsule())
                        .foregroundStyle(Color.screen)
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
                    .foregroundStyle(isSelected ? Color.ink : Color.secondary.opacity(0.4))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                isSelected ? Color.ink.opacity(0.08) : Color.card,
                in: RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: zotInnerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.ink.opacity(0.35) : Color.cardBorder,
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

// MARK: - Hall status inside 3-up cards

/// Short card subtext — meal name only (Atharv: no “tomorrow · 7:15 AM” essays).
private enum HallChromeStatus {
    static func resolve(for location: DiningLocation, nowMinutes: Int = UCITime.nowMinutes()) -> (text: String, tint: Color) {
        if location.comingSoonSubtitle != nil {
            return ("Coming Soon", .secondary)
        }
        switch location.openState(nowMinutes: nowMinutes) {
        case .open(let period, _):
            return (mealLabel(period), .openGreen)
        case .openingLater(let period, _):
            return (mealLabel(period), .busyOrange)
        case .awaitingMoreMeals:
            return ("Later", .busyOrange)
        case .closedForToday:
            if let meal = location.opensTomorrowPeriod {
                return (mealLabel(meal), .secondary)
            }
            if let meal = location.opensNextPeriod {
                return (mealLabel(meal), .secondary)
            }
            return ("Closed", .secondary)
        case .unknown:
            return ("Soon", .secondary)
        }
    }

    private static func mealLabel(_ live: String) -> String {
        MealPeriodPill.canonical(live)
    }
}

// MARK: - Dish row card

private struct DishRowCard: View {
    let item: MenuItem
    let isFavorite: Bool
    var isOnPlate: Bool = false
    var stars: Int = 0
    let onToggleFavorite: () -> Void
    var onTogglePlate: (() -> Void)?
    var onRate: ((Int) -> Void)?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(ZotFont.body)
                        .multilineTextAlignment(.leading)

                    StarRatingControl(stars: stars, size: 12, interactive: onRate != nil, onRate: onRate)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            DishRowAccessibility.label(
                dishName: item.name,
                calories: item.calories,
                dietaryTags: item.dietaryTags,
                allergens: item.allergens,
                stars: stars > 0 ? stars : nil
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
                .foregroundStyle(isOnPlate ? Color.ink : Color.ink.opacity(0.85))
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
                .font(ZotFont.face(14, relativeTo: .caption).weight(.medium))
                .foregroundStyle(Color.ink)
            Text("cal")
                .font(ZotFont.face(9, relativeTo: .caption2).weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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
