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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Remove
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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.atharvgupta.anteats.data.DiningLocation
import com.atharvgupta.anteats.data.DiningLogic
import com.atharvgupta.anteats.data.EatPostedDay
import com.atharvgupta.anteats.data.MenuItem
import com.atharvgupta.anteats.data.MenuStation
import com.atharvgupta.anteats.data.PacificTime
import com.atharvgupta.anteats.data.PlateEntry
import com.atharvgupta.anteats.data.PlateStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EatScreen(
    screenshotMode: String? = null,
    viewModel: EatViewModel = viewModel(),
) {
    val state by viewModel.state.collectAsState()
    val plateEntries by viewModel.plate.entries.collectAsState()
    val colors = MaterialTheme.colorScheme

    LaunchedEffect(state.screenshotReady, screenshotMode) {
        if (state.screenshotReady && screenshotMode != null && state.selectedDish == null && !state.showPlate) {
            viewModel.applyScreenshot(screenshotMode)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.background)
            .statusBarsPadding()
            .testTag("eat-screen"),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = if (plateEntries.isNotEmpty()) 88.dp else 32.dp),
        ) {
            item {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text("Eat", fontSize = 34.sp, fontWeight = FontWeight.Bold, color = colors.onBackground)
                    Text(
                        whatsFor(state.selectedPeriod),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(16.dp))
                    HallRow(
                        halls = state.halls,
                        selected = state.selectedHall,
                        onSelect = viewModel::selectHall,
                    )
                    Spacer(Modifier.height(14.dp))
                    MealPills(
                        selected = state.selectedPeriod,
                        onSelect = viewModel::selectPeriod,
                    )
                    Spacer(Modifier.height(12.dp))
                    DateStrip(
                        days = state.days,
                        selected = state.selectedDate,
                        onSelect = viewModel::selectDate,
                        onPlate = { viewModel.showPlate(true) },
                        plateCount = plateEntries.sumOf { it.quantity },
                    )
                }
            }

            when {
                state.loading && state.menu == null -> item {
                    Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = colors.onBackground)
                    }
                }
                state.error != null && state.menu == null -> item {
                    EmptyCopy(state.error!!)
                }
                else -> {
                    val hall = state.halls.firstOrNull { it.id == state.selectedHall }
                    val stations = state.menu?.stations.orEmpty()
                    if (stations.isEmpty()) {
                        item {
                            EmptyCopy(
                                DiningLogic.emptyMenuCopy(
                                    period = state.selectedPeriod,
                                    browsingFuture = state.selectedDate != PacificTime.todayISO(),
                                    comingSoon = hall?.isComingSoon == true,
                                ),
                            )
                        }
                    } else {
                        items(stations, key = { it.stationID ?: it.name }) { station ->
                            StationBlock(
                                station = station,
                                plate = viewModel.plate,
                                onOpen = viewModel::openDish,
                            )
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
                plate = viewModel.plate,
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
}

private fun whatsFor(period: String): String = when (DiningLogic.canonicalPill(period)) {
    "Breakfast" -> "What's for Breakfast"
    "Lunch" -> "What's for Lunch"
    "Dinner" -> "What's for Dinner"
    else -> "What's for $period"
}

@Composable
private fun HallRow(
    halls: List<DiningLocation>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        val shown = halls.ifEmpty { emptyList() }
        shown.forEach { hall ->
            val active = hall.id == selected
            Column(
                modifier = Modifier
                    .weight(1f)
                    .height(72.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (active) colors.onBackground.copy(alpha = 0.06f) else colors.surface)
                    .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(20.dp))
                    .clickable { onSelect(hall.id) }
                    .padding(horizontal = 6.dp, vertical = 10.dp)
                    .testTag("hall-${hall.compactName.lowercase()}")
                    .semantics { contentDescription = hall.compactName },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    hall.compactName,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = colors.onBackground,
                )
                Text(
                    hallStatus(hall),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (hall.openNow) OpenGreen else colors.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

private fun hallStatus(hall: DiningLocation): String = when {
    hall.isComingSoon -> hall.comingSoonSubtitle ?: "Coming soon"
    hall.openNow -> "Open"
    else -> "Closed"
}

@Composable
private fun MealPills(selected: String, onSelect: (String) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        DiningLogic.mealSelectorPills.forEach { pill ->
            val active = pill.equals(selected, true)
            Text(
                pill,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(999.dp))
                    .background(if (active) colors.onBackground else colors.surface)
                    .border(1.dp, if (active) colors.onBackground else colors.outline, RoundedCornerShape(999.dp))
                    .clickable { onSelect(pill) }
                    .padding(vertical = 10.dp)
                    .testTag("meal-$pill"),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                color = if (active) colors.background else colors.onBackground,
            )
        }
    }
}

@Composable
private fun DateStrip(
    days: List<EatPostedDay>,
    selected: String,
    onSelect: (String) -> Unit,
    onPlate: () -> Unit,
    plateCount: Int,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier.fillMaxWidth(),
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
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (active) colors.onBackground.copy(alpha = 0.12f) else colors.surface)
                        .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(999.dp))
                        .clickable { onSelect(day.isoDate) }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                        .testTag("day-${day.isoDate}"),
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                    fontSize = 13.sp,
                    color = colors.onBackground,
                )
            }
        }
        Text(
            if (plateCount > 0) "My Plate · $plateCount" else "My Plate",
            modifier = Modifier
                .clip(RoundedCornerShape(999.dp))
                .background(colors.surface)
                .border(1.dp, colors.outline, RoundedCornerShape(999.dp))
                .clickable(onClick = onPlate)
                .padding(horizontal = 10.dp, vertical = 6.dp)
                .testTag("my-plate-chip"),
            fontWeight = FontWeight.SemiBold,
            fontSize = 13.sp,
            color = colors.onBackground,
        )
    }
}

@Composable
private fun StationBlock(
    station: MenuStation,
    plate: PlateStore,
    onOpen: (MenuItem) -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
        Text(
            station.name,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = colors.onBackground,
            modifier = Modifier.padding(bottom = 8.dp),
        )
        station.items.forEach { item ->
            DishRow(item = item, quantity = plate.quantity(item.name), onOpen = { onOpen(item) }, onAdd = { plate.add(item) })
        }
    }
}

@Composable
private fun DishRow(
    item: MenuItem,
    quantity: Int,
    onOpen: () -> Unit,
    onAdd: () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
            .clickable(onClick = onOpen)
            .testTag("dish-${item.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(item.name, fontWeight = FontWeight.Medium, color = colors.onBackground)
            val bits = buildList {
                item.calories?.let { add("$it cal") }
                item.servingSize?.let { add(it) }
                if (item.dietaryTags.any { it.equals("Vegan", true) }) add("Vegan")
            }
            if (bits.isNotEmpty()) {
                Text(bits.joinToString(" · "), fontSize = 13.sp, color = colors.onSurfaceVariant)
            }
        }
        IconButton(onClick = onAdd, modifier = Modifier.testTag("add-${item.id}")) {
            Box(
                Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(colors.onBackground.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                if (quantity > 0) {
                    Text("$quantity", fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = colors.onBackground)
                } else {
                    Icon(Icons.Default.Add, contentDescription = "Add to Plate", tint = colors.onBackground, modifier = Modifier.size(16.dp))
                }
            }
        }
    }
}

@Composable
private fun EmptyCopy(text: String) {
    Text(
        text,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 28.dp),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.Medium,
    )
}

@Composable
private fun PlateBar(
    count: Int,
    calories: Int,
    protein: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.colorScheme
    Row(
        modifier
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(colors.onBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .testTag("plate-bar"),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            if (count == 1) "1 on your plate" else "$count on your plate",
            color = colors.background,
            fontWeight = FontWeight.SemiBold,
        )
        Text("$calories cal · ${protein}g protein", color = colors.background, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun DishDetail(dish: MenuItem, plate: PlateStore, onClose: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val quantity = plate.quantity(dish.name)
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp)
            .testTag("dish-detail"),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(dish.name, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = colors.onBackground, modifier = Modifier.weight(1f).padding(end = 12.dp))
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = colors.onBackground)
            }
        }
        dish.description?.takeIf { it.isNotBlank() }?.let {
            Text(it, color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium, modifier = Modifier.padding(top = 6.dp))
        }
        if (dish.dietaryTags.isNotEmpty() || dish.allergens.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            FlowChips(dish.dietaryTags + dish.allergens.map { "Allergen: $it" })
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatCard(dish.calories?.toString() ?: "-", "Calories")
            StatCard(dish.servingSize ?: "-", "Serving")
            dish.nutrition?.proteinG?.let { StatCard("${it.toInt()}g", "Protein") }
        }
        dish.nutrition?.takeIf { it.hasMacros }?.let { facts ->
            Spacer(Modifier.height(14.dp))
            Text("Nutrition", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            MacroLine("Protein", facts.proteinG, "g")
            MacroLine("Carbs", facts.totalCarbsG, "g")
            MacroLine("Fat", facts.totalFatG, "g")
            MacroLine("Saturated fat", facts.saturatedFatG, "g")
            MacroLine("Sodium", facts.sodiumMg, "mg")
            MacroLine("Sugars", facts.sugarsG, "g")
            MacroLine("Fiber", facts.dietaryFiberG, "g")
            facts.ingredients?.let {
                Spacer(Modifier.height(8.dp))
                Text("Ingredients", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
                Text(it, color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium)
            }
        }
        Spacer(Modifier.height(20.dp))
        val label = if (quantity > 0) "On your plate ($quantity)" else "Add to Plate"
        Text(
            label,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(999.dp))
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

@Composable
private fun StatCard(value: String, label: String) {
    val colors = MaterialTheme.colorScheme
    Column(
        Modifier
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, colors.outline, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Text(value, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
        Text(label, fontSize = 12.sp, color = colors.onSurfaceVariant)
    }
}

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
private fun FlowChips(tags: List<String>) {
    val colors = MaterialTheme.colorScheme
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.horizontalScroll(rememberScrollState())) {
        tags.forEach { tag ->
            Text(
                tag,
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(colors.surfaceVariant)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.onBackground,
            )
        }
    }
}

@Composable
private fun PlateSheet(entries: List<PlateEntry>, plate: PlateStore, onClose: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp)
            .testTag("plate-sheet"),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Column(Modifier.weight(1f)) {
                Text("My Plate", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = colors.onBackground)
                Text("Today's picks. Totals include every serving.", color = colors.onSurfaceVariant, fontWeight = FontWeight.Medium)
            }
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = colors.onBackground)
            }
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            StatCard("${plate.totalCalories} cal", "Calories")
            StatCard("${plate.totalProteinG}g", "Protein")
        }
        Spacer(Modifier.height(16.dp))
        if (entries.isEmpty()) {
            Text("Nothing on your plate yet", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            Text("Tap + on a dish, or open it and choose Add to Plate.", color = colors.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
            Text("Clears each morning.", color = colors.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
        } else {
            entries.forEach { entry ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.dp, colors.outline, RoundedCornerShape(16.dp))
                        .padding(horizontal = 14.dp, vertical = 12.dp),
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
            Spacer(Modifier.height(12.dp))
            Text(
                "Clear plate",
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(999.dp))
                    .background(colors.onBackground.copy(alpha = 0.06f))
                    .clickable { plate.clear() }
                    .padding(vertical = 13.dp),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold,
                color = colors.onBackground,
            )
        }
    }
}


