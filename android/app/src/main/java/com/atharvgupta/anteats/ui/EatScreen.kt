package com.atharvgupta.anteats.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.atharvgupta.anteats.data.DiningLocation
import com.atharvgupta.anteats.data.DiningLogic
import com.atharvgupta.anteats.data.EatPostedDay
import com.atharvgupta.anteats.data.HallChrome
import com.atharvgupta.anteats.data.HallDirectory
import com.atharvgupta.anteats.data.HallTone
import com.atharvgupta.anteats.data.MenuItem
import com.atharvgupta.anteats.data.MenuStation
import com.atharvgupta.anteats.data.PacificTime
import com.atharvgupta.anteats.data.PlateEntry
import com.atharvgupta.anteats.data.PlateStore
import com.atharvgupta.anteats.data.PreferencesStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EatScreen(
    screenshotMode: String? = null,
    onSettings: () -> Unit,
    viewModel: EatViewModel,
) {
    val state by viewModel.state.collectAsState()
    val plateEntries by viewModel.plate.entries.collectAsState()
    val diets by viewModel.prefs.diets.collectAsState()
    val allergens by viewModel.prefs.allergens.collectAsState()
    val favorites by viewModel.prefs.favorites.collectAsState()
    val reviews by viewModel.prefs.reviews.collectAsState()
    val colors = MaterialTheme.colorScheme
    val today = PacificTime.todayISO()
    val browsingFuture = state.selectedDate != today

    LaunchedEffect(state.screenshotReady, screenshotMode) {
        if (state.screenshotReady && screenshotMode != null &&
            state.selectedDish == null && !state.showPlate && !state.showFilters
        ) {
            viewModel.applyScreenshot(screenshotMode)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.background)
            .testTag("eat-screen"),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 12.dp, bottom = if (plateEntries.isNotEmpty()) 88.dp else 40.dp),
        ) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    ScreenHeader(
                        title = "Eat",
                        subtitle = whatsFor(state.selectedPeriod),
                        onSettings = onSettings,
                    )
                    HallRow(
                        halls = state.halls,
                        selected = state.selectedHall,
                        onSelect = viewModel::selectHall,
                    )
                    val hall = state.halls.firstOrNull { it.id == state.selectedHall }
                    if (hall?.isComingSoon != true) {
                        MealPills(
                            selected = state.selectedPeriod,
                            available = hall?.availablePeriods.orEmpty(),
                            onSelect = viewModel::selectPeriod,
                        )
                        DateActionRow(
                            days = state.days,
                            selected = state.selectedDate,
                            onSelect = viewModel::selectDate,
                            onPlate = { viewModel.showPlate(true) },
                            plateOpen = state.showPlate,
                            onFilters = { viewModel.showFilters(true) },
                            filtersActive = diets.isNotEmpty() || allergens.isNotEmpty(),
                            onClear = { viewModel.prefs.clearFilters() },
                        )
                    }
                }
            }

            when {
                state.loading && state.menu == null -> item {
                    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        repeat(4) { SkeletonCard(96.dp) }
                    }
                }
                state.error != null && state.menu == null -> item {
                    EmptyState(
                        icon = Icons.Outlined.Restaurant,
                        title = "Can't reach UCI Dining",
                        message = state.error!!,
                        actionTitle = "Try Again",
                        onAction = viewModel::refresh,
                    )
                }
                else -> {
                    val hall = state.halls.firstOrNull { it.id == state.selectedHall }
                    if (hall?.isComingSoon == true) {
                        item {
                            EmptyState(
                                icon = Icons.Outlined.Apartment,
                                title = hall.name,
                                message = DiningLogic.emptyMenuCopy(state.selectedPeriod, browsingFuture, comingSoon = true),
                            )
                        }
                    } else {
                        val stations = filteredStations(state.menu?.stations.orEmpty(), viewModel.prefs)
                        val favoriteItems = stations.flatMap { it.items }.filter { viewModel.prefs.isFavorite(it.name) }
                        if (stations.isEmpty()) {
                            item {
                                EmptyState(
                                    icon = Icons.Outlined.Restaurant,
                                    title = if (diets.isNotEmpty() || allergens.isNotEmpty()) "Nothing matches" else "No menu posted yet",
                                    message = if (diets.isNotEmpty() || allergens.isNotEmpty()) {
                                        "No dishes match these filters. Clear them to see the full board."
                                    } else {
                                        DiningLogic.emptyMenuCopy(state.selectedPeriod, browsingFuture, comingSoon = false)
                                    },
                                    actionTitle = if (diets.isNotEmpty() || allergens.isNotEmpty()) "Clear filters" else null,
                                    onAction = if (diets.isNotEmpty() || allergens.isNotEmpty()) ({ viewModel.prefs.clearFilters() }) else null,
                                )
                            }
                        } else {
                            if (favoriteItems.isNotEmpty()) {
                                item {
                                    Column(
                                        Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                                        verticalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        SectionHeader("Favorites today", favoriteItems.size, goldBar = false, icon = Icons.Filled.Favorite)
                                        favoriteItems.forEach { item ->
                                            DishRowCard(
                                                item = item,
                                                favorite = true,
                                                quantity = viewModel.plate.quantity(item.name),
                                                stars = viewModel.prefs.stars(item.name),
                                                onOpen = { viewModel.openDish(item) },
                                                onFavorite = { viewModel.prefs.toggleFavorite(item.name) },
                                                onAdd = { viewModel.plate.add(item) },
                                                onRate = { viewModel.prefs.setStars(item.name, it) },
                                            )
                                        }
                                    }
                                }
                            }
                            items(stations, key = { it.stationID ?: it.name }) { station ->
                                StationBlock(
                                    station = station,
                                    prefs = viewModel.prefs,
                                    plate = viewModel.plate,
                                    onOpen = viewModel::openDish,
                                )
                            }
                        }
                    }
                }
            }
        }

        if (plateEntries.isNotEmpty()) {
            PlateBar(
                count = plateEntries.sumOf { it.quantity },
                calories = viewModel.plate.totalCalories,
                protein = viewModel.plate.totalProteinG,
                browsingFuture = browsingFuture,
                onClick = { viewModel.showPlate(true) },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }

    val dish = state.selectedDish
    if (dish != null) {
        ModalBottomSheet(
            onDismissRequest = viewModel::closeDish,
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.background,
        ) {
            DishDetail(
                dish = dish,
                plate = if (browsingFuture) null else viewModel.plate,
                prefs = viewModel.prefs,
                onClose = viewModel::closeDish,
            )
        }
    }

    if (state.showPlate) {
        ModalBottomSheet(
            onDismissRequest = { viewModel.showPlate(false) },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.background,
        ) {
            PlateSheet(
                entries = plateEntries,
                plate = viewModel.plate,
                onClose = { viewModel.showPlate(false) },
            )
        }
    }

    if (state.showFilters) {
        ModalBottomSheet(
            onDismissRequest = { viewModel.showFilters(false) },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.background,
        ) {
            FilterSheet(prefs = viewModel.prefs, onDone = { viewModel.showFilters(false) })
        }
    }

    // Keep collected flows live so favorite/filter recomposition stays honest.
    @Suppress("UNUSED_VARIABLE")
    val keep = favorites.size + reviews.size + diets.size + allergens.size
}

private fun whatsFor(period: String): String = when (DiningLogic.canonicalPill(period)) {
    "Breakfast" -> "What's for Breakfast"
    "Lunch" -> "What's for Lunch"
    "Dinner" -> "What's for Dinner"
    "Afternoon Snack" -> "What's for Afternoon Snack"
    "Late Night" -> "What's for Late Night"
    else -> "What's for $period"
}

private fun filteredStations(stations: List<MenuStation>, prefs: PreferencesStore): List<MenuStation> {
    val tagged = stations.map { station ->
        station.withItems(DiningLogic.applyStationTags(station.items, station.name, station.stationID))
    }
    return DiningLogic.pinTwistedRootFirst(
        tagged.mapNotNull { station ->
            val items = station.items.filter { prefs.matches(it) }
            if (items.isEmpty()) null else station.withItems(items)
        },
    )
}

@Composable
private fun HallRow(
    halls: List<DiningLocation>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    val now = PacificTime.nowMinutes()
    val today = PacificTime.todayISO()
    val gold = accentGold()
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        halls.ifEmpty {
            listOf(
                DiningLocation(HallDirectory.ANTEATERY, "The Anteatery", "Anteatery", "Mesa Court", false, null, emptyList(), emptyList()),
                DiningLocation(HallDirectory.BRANDYWINE, "Brandywine", "Brandywine", "Middle Earth", false, null, emptyList(), emptyList()),
                DiningLocation(HallDirectory.OASIS, "The Oasis", "Oasis", "Mesa Court", false, null, emptyList(), emptyList(), "Coming soon"),
            )
        }.forEach { hall ->
            val active = hall.id == selected
            val status = HallChrome.status(hall, now, today)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .height(HallTileHeight)
                    .clip(RoundedCornerShape(HallRadius))
                    .background(if (active) gold.copy(alpha = 0.12f) else MaterialTheme.colorScheme.surface)
                    .border(
                        1.dp,
                        if (active) gold.copy(alpha = 0.45f) else MaterialTheme.colorScheme.outline,
                        RoundedCornerShape(HallRadius),
                    )
                    .clickable { onSelect(hall.id) }
                    .padding(horizontal = 6.dp)
                    .testTag("hall-${hall.compactName.lowercase()}")
                    .semantics { contentDescription = hall.compactName },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    hall.compactName,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = HallNameSize,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onBackground,
                    modifier = Modifier.height(34.dp),
                )
                Text(
                    status.primary,
                    fontSize = HallStatusSize,
                    fontWeight = FontWeight.Medium,
                    color = if (status.tone == HallTone.Open) OpenGreen else MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.height(18.dp),
                )
            }
        }
    }
}

@Composable
private fun MealPills(selected: String, available: List<String>, onSelect: (String) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        DiningLogic.mealSelectorPills.forEach { pill ->
            val active = pill.equals(selected, true)
            val posted = DiningLogic.pillIsPosted(pill, available)
            Text(
                pill,
                modifier = Modifier
                    .height(36.dp)
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(if (active) colors.onBackground.copy(alpha = 0.06f) else colors.background)
                    .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.28f) else colors.outline, RoundedCornerShape(ChipRadius))
                    .clickable { onSelect(pill) }
                    .padding(horizontal = 10.dp, vertical = 7.dp)
                    .testTag("meal-$pill"),
                textAlign = TextAlign.Center,
                fontSize = PillTextSize,
                fontWeight = if (active) FontWeight.Bold else FontWeight.SemiBold,
                color = colors.onBackground.copy(alpha = if (posted || active) 1f else 0.45f),
            )
        }
    }
}

@Composable
private fun DateActionRow(
    days: List<EatPostedDay>,
    selected: String,
    onSelect: (String) -> Unit,
    onPlate: () -> Unit,
    plateOpen: Boolean,
    onFilters: () -> Unit,
    filtersActive: Boolean,
    onClear: () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            Modifier
                .weight(1f)
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            days.forEach { day ->
                val active = day.isoDate == selected
                Text(
                    day.label,
                    modifier = Modifier
                        .clip(RoundedCornerShape(ChipRadius))
                        .background(if (active) colors.onBackground.copy(alpha = 0.06f) else colors.surface)
                        .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.28f) else colors.outline, RoundedCornerShape(ChipRadius))
                        .clickable { onSelect(day.isoDate) }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .testTag("day-${day.isoDate}"),
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                    fontSize = 13.sp,
                    color = colors.onBackground,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            ActionChip(
                label = "Plate",
                active = plateOpen,
                icon = { Icon(Icons.Outlined.Restaurant, contentDescription = null, modifier = Modifier.size(13.dp), tint = it) },
                onClick = onPlate,
                tag = "my-plate-chip",
            )
            ActionChip(
                label = "Filters",
                active = filtersActive,
                icon = { Icon(Icons.Outlined.FilterList, contentDescription = null, modifier = Modifier.size(13.dp), tint = it) },
                onClick = onFilters,
                tag = "diet-filter-chip",
            )
            if (filtersActive) {
                Text(
                    "Clear",
                    modifier = Modifier
                        .clip(RoundedCornerShape(ChipRadius))
                        .background(colors.onBackground.copy(alpha = 0.08f))
                        .clickable(onClick = onClear)
                        .padding(horizontal = 8.dp, vertical = 5.dp)
                        .testTag("diet-filter-clear"),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                    color = colors.onBackground,
                )
            }
        }
    }
}

@Composable
private fun ActionChip(
    label: String,
    active: Boolean,
    icon: @Composable (androidx.compose.ui.graphics.Color) -> Unit,
    onClick: () -> Unit,
    tag: String,
) {
    val colors = MaterialTheme.colorScheme
    val tint = if (active) colors.onBackground else colors.onSurfaceVariant
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(ChipRadius))
            .background(if (active) colors.onBackground.copy(alpha = 0.12f) else colors.surface)
            .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(ChipRadius))
            .clickable(onClick = onClick)
            .padding(horizontal = 9.dp, vertical = 5.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        icon(tint)
        Text(label, fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium, fontSize = 13.sp, color = tint)
    }
}

@Composable
private fun StationBlock(
    station: MenuStation,
    prefs: PreferencesStore,
    plate: PlateStore,
    onOpen: (MenuItem) -> Unit,
) {
    var expanded by remember(station.name) { mutableStateOf(!station.name.contains("all day", true)) }
    val isAllDay = station.name.contains("all day", true)
    Column(
        Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .then(if (isAllDay) Modifier.clickable { expanded = !expanded } else Modifier),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SectionHeader(station.name, station.items.size)
        }
        if (expanded) {
            station.items.forEach { item ->
                DishRowCard(
                    item = item,
                    favorite = prefs.isFavorite(item.name),
                    quantity = plate.quantity(item.name),
                    stars = prefs.stars(item.name),
                    onOpen = { onOpen(item) },
                    onFavorite = { prefs.toggleFavorite(item.name) },
                    onAdd = { plate.add(item) },
                    onRate = { prefs.setStars(item.name, it) },
                )
            }
        }
    }
}

@Composable
private fun DishRowCard(
    item: MenuItem,
    favorite: Boolean,
    quantity: Int,
    stars: Int,
    onOpen: () -> Unit,
    onFavorite: () -> Unit,
    onAdd: () -> Unit,
    onRate: (Int) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .zotCard()
            .clickable(onClick = onOpen)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .testTag("dish-${item.id}"),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(item.name, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            StarRating(stars = stars, size = 12.dp, onRate = onRate)
            item.description?.takeIf { it.isNotBlank() }?.let {
                Text(it, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            if (item.dietaryTags.isNotEmpty() || item.allergens.isNotEmpty()) {
                Row(
                    Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    item.dietaryTags.forEach { TagChip(it, dietColor(it)) }
                    item.allergens.forEach { TagChip(it, Terracotta) }
                }
            }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = onAdd, modifier = Modifier.size(30.dp).testTag("add-${item.id}")) {
                    Icon(
                        if (quantity > 0) Icons.Rounded.AddCircle else Icons.Filled.Add,
                        contentDescription = "Add to Plate",
                        tint = if (quantity > 0) colors.onBackground else colors.onSurfaceVariant,
                    )
                }
                IconButton(onClick = onFavorite, modifier = Modifier.size(30.dp)) {
                    Icon(
                        if (favorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = if (favorite) "Remove from favorites" else "Add to favorites",
                        tint = if (favorite) FavoritePink else colors.onSurfaceVariant,
                    )
                }
            }
            item.calories?.let {
                Text("$it cal", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun PlateBar(
    count: Int,
    calories: Int,
    protein: Int,
    browsingFuture: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.colorScheme
    val title = when {
        browsingFuture && count == 1 -> "Today's plate · 1"
        browsingFuture -> "Today's plate · $count"
        count == 1 -> "1 on your plate"
        else -> "$count on your plate"
    }
    Row(
        modifier
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 6.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(ChipRadius))
            .background(if (browsingFuture) colors.onBackground.copy(alpha = 0.12f) else colors.onBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 11.dp)
            .testTag("plate-bar"),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = if (browsingFuture) colors.onBackground else colors.background, fontWeight = FontWeight.SemiBold)
        Text(
            "$calories cal · ${protein}g protein",
            color = if (browsingFuture) colors.onBackground else colors.background,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun DishDetail(dish: MenuItem, plate: PlateStore?, prefs: PreferencesStore, onClose: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val quantity = plate?.quantity(dish.name) ?: 0
    val favorite = prefs.isFavorite(dish.name)
    val stars = prefs.stars(dish.name)
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
            .padding(bottom = 12.dp)
            .testTag("dish-detail"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(dish.name, fontSize = SheetHeroSize, fontWeight = FontWeight.Bold, color = colors.onBackground, modifier = Modifier.weight(1f).padding(end = 12.dp))
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = colors.onSurfaceVariant)
            }
        }
        dish.description?.takeIf { it.isNotBlank() }?.let {
            Text(it, color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium)
        }
        if (dish.dietaryTags.isNotEmpty() || dish.allergens.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
                dish.dietaryTags.forEach { TagChip(it, dietColor(it)) }
                dish.allergens.forEach { TagChip(it, Terracotta) }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatCard(dish.calories?.toString() ?: "-", "Calories")
            StatCard(dish.servingSize ?: "-", "Serving")
        }
        dish.nutrition?.takeIf { it.hasMacros }?.let { facts ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                MacroCard(facts.proteinG, "Protein", Sage)
                MacroCard(facts.totalCarbsG, "Carbs", Slate)
                MacroCard(facts.totalFatG, "Fat", Terracotta)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Your rating", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            StarRating(stars = stars, size = 28.dp, onRate = { prefs.setStars(dish.name, it) })
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { prefs.toggleFavorite(dish.name) }) {
                Icon(
                    if (favorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = "Favorite",
                    tint = if (favorite) FavoritePink else colors.onSurfaceVariant,
                )
            }
            Text(if (favorite) "Saved to favorites" else "Save as favorite", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
        }
        dish.nutrition?.takeIf { it.hasDetails }?.let { facts ->
            Text("Nutrition", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            MacroLine("Saturated fat", facts.saturatedFatG, "g")
            MacroLine("Sodium", facts.sodiumMg, "mg")
            MacroLine("Sugars", facts.sugarsG, "g")
            MacroLine("Fiber", facts.dietaryFiberG, "g")
            facts.ingredients?.let {
                Text("Ingredients", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
                Text(it, color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium)
            }
        }
        if (plate != null) {
            val label = if (quantity > 0) "On your plate ($quantity)" else "Add to Plate"
            Text(
                label,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(colors.onBackground)
                    .clickable { plate.add(dish) }
                    .padding(vertical = 14.dp)
                    .testTag("add-to-plate"),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                color = colors.background,
            )
        }
    }
}

@Composable
private fun StatCard(value: String, label: String) {
    val colors = MaterialTheme.colorScheme
    Column(
        Modifier
            .zotCard()
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Text(value, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
        Text(label, fontSize = 12.sp, color = colors.onSurfaceVariant)
    }
}

@Composable
private fun MacroCard(value: Double?, label: String, tint: androidx.compose.ui.graphics.Color) {
    Column(
        Modifier
            .zotCard()
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .fillMaxWidth()
            .weightIfRow(),
    ) {
        Text(value?.let { formatNum(it) + "g" } ?: "-", fontWeight = FontWeight.SemiBold, color = tint)
        Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun Modifier.weightIfRow(): Modifier = this

@Composable
private fun MacroLine(label: String, value: Double?, unit: String) {
    if (value == null) return
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("${formatNum(value)} $unit", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onBackground)
    }
}

private fun formatNum(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else String.format("%.1f", value)

@Composable
private fun PlateSheet(entries: List<PlateEntry>, plate: PlateStore, onClose: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    var confirmClear by remember { mutableStateOf(false) }
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
            .testTag("plate-sheet"),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column(Modifier.weight(1f).padding(end = 44.dp)) {
                Text("My Plate", fontSize = SheetHeroSize, fontWeight = FontWeight.Bold, color = colors.onBackground)
                Text("Today's picks. Totals include every serving.", color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium)
            }
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close plate", tint = colors.onSurfaceVariant)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            StatCard("${plate.totalCalories} cal", "Calories")
            StatCard("${plate.totalProteinG}g", "Protein")
        }
        if (entries.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(vertical = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Nothing on your plate yet", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
                Text("Tap + on a dish, or open it and choose Add to Plate.", color = colors.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp), textAlign = TextAlign.Center)
                Text("Clears each morning.", color = colors.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
            }
        } else {
            entries.forEach { entry ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .zotCard()
                        .padding(horizontal = 14.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(entry.dish.name, fontWeight = FontWeight.Medium, color = colors.onBackground)
                        Text("${entry.lineCalories} cal", fontSize = 13.sp, color = colors.onSurfaceVariant)
                    }
                    IconButton(onClick = { plate.setQuantity(entry.dish.name, entry.quantity - 1) }) {
                        Icon(Icons.Default.Remove, contentDescription = "Fewer", tint = colors.onBackground)
                    }
                    Text("${entry.quantity}", fontWeight = FontWeight.SemiBold, modifier = Modifier.width(20.dp), textAlign = TextAlign.Center)
                    IconButton(onClick = { plate.add(entry.dish) }) {
                        Icon(Icons.Default.Add, contentDescription = "More", tint = colors.onBackground)
                    }
                }
            }
            Text(
                if (confirmClear) "Tap again to clear" else "Clear plate",
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(colors.onBackground.copy(alpha = 0.05f))
                    .clickable {
                        if (plate.servingCount >= 2 && !confirmClear) confirmClear = true
                        else plate.clear()
                    }
                    .padding(vertical = 13.dp),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                color = colors.onBackground,
            )
        }
    }
}

@Composable
private fun FilterSheet(prefs: PreferencesStore, onDone: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val diets by prefs.diets.collectAsState()
    val allergens by prefs.allergens.collectAsState()
    val dietOptions = listOf("Vegan", "Vegetarian", "Halal", "Kosher", "Gluten-Free")
    val allergenOptions = listOf("Eggs", "Fish", "Milk", "Peanuts", "Sesame", "Shellfish", "Soy", "Tree Nuts", "Wheat")
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
            .testTag("filter-sheet"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Filters", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = colors.onBackground, modifier = Modifier.weight(1f))
            Text(
                "Done",
                modifier = Modifier
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(colors.onBackground)
                    .clickable(onClick = onDone)
                    .padding(horizontal = 16.dp, vertical = 7.dp)
                    .testTag("diet-filter-done"),
                fontWeight = FontWeight.SemiBold,
                color = colors.background,
            )
        }
        Text("Diet - dishes must match all selected.", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant, modifier = Modifier.padding(bottom = 6.dp, top = 8.dp))
        dietOptions.forEach { option ->
            FilterRow(
                title = option,
                subtitle = "Only ${option.lowercase()} dishes",
                color = dietColor(option),
                selected = option in diets,
                onToggle = { prefs.toggleDiet(option) },
            )
        }
        Text("Avoid allergens - hides dishes that list them.", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant, modifier = Modifier.padding(top = 14.dp, bottom = 6.dp))
        Text("Only works when UCI publishes allergen data for that dish.", fontSize = 13.sp, color = colors.onSurfaceVariant.copy(alpha = 0.7f), modifier = Modifier.padding(bottom = 4.dp))
        allergenOptions.forEach { option ->
            FilterRow(
                title = option,
                subtitle = "Hide dishes with ${option.lowercase()}",
                color = Terracotta,
                selected = option in allergens,
                onToggle = { prefs.toggleAllergen(option) },
            )
        }
        if (diets.isNotEmpty() || allergens.isNotEmpty()) {
            Text(
                "Clear all",
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(colors.onBackground.copy(alpha = 0.05f))
                    .clickable { prefs.clearFilters() }
                    .padding(vertical = 13.dp),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                color = colors.onBackground,
            )
        }
    }
}

@Composable
private fun FilterRow(title: String, subtitle: String, color: androidx.compose.ui.graphics.Color, selected: Boolean, onToggle: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(InnerRadius))
            .background(if (selected) colors.onBackground.copy(alpha = 0.08f) else colors.surface)
            .border(1.dp, if (selected) colors.onBackground.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(InnerRadius))
            .clickable(onClick = onToggle)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TagChip(title, color)
        Text(subtitle, fontWeight = FontWeight.Medium, color = colors.onBackground, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Icon(
            if (selected) Icons.Rounded.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (selected) colors.onBackground else colors.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp),
        )
    }
}
