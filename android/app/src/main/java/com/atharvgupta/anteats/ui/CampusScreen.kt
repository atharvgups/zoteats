package com.atharvgupta.anteats.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.LocalGroceryStore
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.atharvgupta.anteats.data.CampusPlace
import com.atharvgupta.anteats.data.CampusRepository
import com.atharvgupta.anteats.data.PreferencesStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CampusUiState(
    val places: List<CampusPlace> = emptyList(),
    val loading: Boolean = true,
    val error: String? = null,
    val filter: String = "All",
    val openOnly: Boolean = false,
)

class CampusViewModel(
    private val repository: CampusRepository = CampusRepository(),
    val prefs: PreferencesStore,
) : ViewModel() {
    private val _state = MutableStateFlow(CampusUiState())
    val state = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            runCatching { repository.places() }
                .onSuccess { places -> _state.update { it.copy(places = places, loading = false) } }
                .onFailure {
                    _state.update {
                        it.copy(loading = false, error = "Could not load campus spots. Pull to refresh.")
                    }
                }
        }
    }

    fun setFilter(filter: String) {
        _state.update { it.copy(filter = filter) }
    }

    fun toggleOpenOnly() {
        _state.update { it.copy(openOnly = !it.openOnly) }
    }
}

class CampusViewModelFactory(private val prefs: PreferencesStore) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = CampusViewModel(prefs = prefs) as T
}

@Composable
fun CampusScreen(
    onSettings: () -> Unit,
    prefs: PreferencesStore,
    viewModel: CampusViewModel = viewModel(factory = CampusViewModelFactory(prefs)),
) {
    val state by viewModel.state.collectAsState()
    val favorites by prefs.campusFavorites.collectAsState()
    val colors = MaterialTheme.colorScheme
    val repo = remember { CampusRepository() }

    LaunchedEffect(Unit) { /* keep first paint */ }

    Column(
        Modifier
            .fillMaxSize()
            .background(colors.background)
            .verticalScroll(rememberScrollState())
            .padding(top = 12.dp, bottom = 32.dp)
            .testTag("campus-screen"),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        ScreenHeader(title = "Campus", subtitle = "Cafes, courts, and markets", onSettings = onSettings)
        FilterBar(
            filter = state.filter,
            openOnly = state.openOnly,
            onFilter = viewModel::setFilter,
            onOpenOnly = viewModel::toggleOpenOnly,
        )
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            when {
                state.loading && state.places.isEmpty() -> repeat(6) { SkeletonCard(76.dp) }
                state.error != null && state.places.isEmpty() -> EmptyState(
                    icon = Icons.Outlined.LocalCafe,
                    title = "Couldn't load campus spots",
                    message = state.error!!,
                    actionTitle = "Try Again",
                    onAction = viewModel::refresh,
                )
                else -> {
                    val filtered = state.places.filter { repo.typeMatches(state.filter, it.category) }
                        .filter { !state.openOnly || it.openNow }
                    val favs = filtered.filter { it.id in favorites }
                    val rest = filtered.filter { it.id !in favorites }.sortedWith(
                        compareBy<CampusPlace> { !it.name.contains("Twisted Root", true) }.thenBy { it.name.lowercase() },
                    )
                    if (favs.isEmpty() && rest.isEmpty()) {
                        EmptyState(
                            icon = Icons.Outlined.LocalCafe,
                            title = if (state.openOnly) "Nothing's open right now" else "Nothing to show",
                            message = if (state.openOnly) "Every campus spot is closed at the moment." else "No campus dining locations are listed right now.",
                            actionTitle = if (state.openOnly) "Show closed spots" else null,
                            onAction = if (state.openOnly) ({ viewModel.toggleOpenOnly() }) else null,
                        )
                    } else {
                        if (favs.isNotEmpty()) {
                            Text("Favorites", fontSize = SectionSize, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
                            favs.forEach { PlaceRow(it, true) { prefs.toggleCampusFavorite(it.id) } }
                        }
                        rest.forEach { PlaceRow(it, it.id in favorites) { prefs.toggleCampusFavorite(it.id) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterBar(filter: String, openOnly: Boolean, onFilter: (String) -> Unit, onOpenOnly: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(ChipRadius))
                .background(if (openOnly) OpenGreen.copy(alpha = 0.12f) else colors.surface)
                .border(1.dp, if (openOnly) OpenGreen.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(ChipRadius))
                .clickable(onClick = onOpenOnly)
                .padding(horizontal = 12.dp, vertical = 7.dp)
                .height(36.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(if (openOnly) OpenGreen else colors.onSurfaceVariant.copy(alpha = 0.4f)))
            Text("Open now", fontSize = 14.sp, fontWeight = if (openOnly) FontWeight.SemiBold else FontWeight.Medium, color = if (openOnly) OpenGreen else colors.onBackground)
        }
        Box(Modifier.height(28.dp).size(width = 1.dp, height = 28.dp).background(colors.outline))
        listOf("All", "Coffee", "Food", "Markets").forEach { item ->
            val active = item == filter
            Text(
                item,
                modifier = Modifier
                    .clip(RoundedCornerShape(ChipRadius))
                    .background(if (active) colors.onBackground.copy(alpha = 0.12f) else colors.surface)
                    .border(1.dp, if (active) colors.onBackground.copy(alpha = 0.35f) else colors.outline, RoundedCornerShape(ChipRadius))
                    .clickable { onFilter(item) }
                    .padding(horizontal = 12.dp, vertical = 7.dp),
                fontSize = 14.sp,
                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                color = colors.onBackground,
            )
        }
    }
}

@Composable
private fun PlaceRow(place: CampusPlace, favorite: Boolean, onFavorite: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val icon = when (place.category) {
        "Coffee & Cafes", "Coffee & Cafés" -> Icons.Outlined.LocalCafe
        "Markets" -> Icons.Outlined.LocalGroceryStore
        else -> Icons.Outlined.Restaurant
    }
    Row(
        Modifier
            .fillMaxWidth()
            .zotCard()
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(InnerRadius))
                .background(colors.onBackground.copy(alpha = if (place.openNow) 0.06f else 0.04f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = if (place.openNow) colors.onBackground else colors.onSurfaceVariant, modifier = Modifier.size(14.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(place.name, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            StatusPill(place.openNow, closedText = place.statusLine)
            place.hoursLine?.let {
                Text(it, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
            }
        }
        Icon(
            if (favorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
            contentDescription = if (favorite) "Remove favorite" else "Favorite",
            tint = if (favorite) FavoritePink else colors.onSurfaceVariant,
            modifier = Modifier.size(20.dp).clickable(onClick = onFavorite),
        )
    }
}
