package com.atharvgupta.anteats.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.atharvgupta.anteats.data.StudyRepository
import com.atharvgupta.anteats.data.StudyZone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class StudyUiState(
    val libraries: List<StudyZone> = emptyList(),
    val loading: Boolean = true,
    val error: String? = null,
)

class StudyViewModel(
    private val repository: StudyRepository = StudyRepository(),
) : ViewModel() {
    private val _state = MutableStateFlow(StudyUiState())
    val state = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            runCatching { repository.libraries() }
                .onSuccess { libs -> _state.update { it.copy(libraries = libs, loading = false) } }
                .onFailure {
                    _state.update { it.copy(loading = false, error = "Could not load busyness. Pull to refresh.") }
                }
        }
    }
}

@Composable
fun StudyScreen(
    onSettings: () -> Unit,
    viewModel: StudyViewModel = viewModel(),
) {
    val state by viewModel.state.collectAsState()
    val colors = MaterialTheme.colorScheme
    val open = state.libraries.filter { it.isOpen && it.percent != null }
    val quietest = open.minByOrNull { it.percent ?: 100 }

    Column(
        Modifier
            .fillMaxSize()
            .background(colors.background)
            .verticalScroll(rememberScrollState())
            .padding(top = 12.dp, bottom = 32.dp)
            .testTag("study-screen"),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        ScreenHeader(title = "Study", subtitle = "Where it's calm right now", onSettings = onSettings)
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            when {
                state.loading && state.libraries.isEmpty() -> repeat(3) { SkeletonCard(88.dp) }
                state.error != null && state.libraries.isEmpty() -> EmptyState(
                    icon = Icons.Outlined.AutoStories,
                    title = "Couldn't load busyness",
                    message = state.error!!,
                    actionTitle = "Try Again",
                    onAction = viewModel::refresh,
                )
                state.libraries.isEmpty() -> EmptyState(
                    icon = Icons.Outlined.AutoStories,
                    title = "All quiet",
                    message = "No spots are reporting right now. Even the ants went home.",
                    actionTitle = "Try Again",
                    onAction = viewModel::refresh,
                )
                else -> {
                    if (quietest != null) {
                        QuietestCard(quietest)
                    } else {
                        QuietestClosedCard()
                    }
                    state.libraries.sortedWith(compareByDescending<StudyZone> { it.isOpen }.thenByDescending { it.percent ?: -1 }).forEach {
                        LibraryCard(it)
                    }
                }
            }
        }
    }
}

@Composable
private fun QuietestCard(zone: StudyZone) {
    val colors = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .zotCard()
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier
                .width(3.dp)
                .height(28.dp)
                .clip(RoundedCornerShape(1.dp))
                .background(accentGold()),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("QUIETEST RIGHT NOW", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
            Text(zone.name, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("${zone.percent}%", fontSize = 24.sp, fontWeight = FontWeight.SemiBold, color = colors.onBackground)
            Text("full", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
        }
    }
}

@Composable
private fun QuietestClosedCard() {
    val colors = MaterialTheme.colorScheme
    Column(
        Modifier
            .fillMaxWidth()
            .zotCard()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("QUIETEST RIGHT NOW", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
        Text("Libraries closed", fontWeight = FontWeight.SemiBold, color = colors.onBackground)
        Text("Check back when Langson or Gateway opens.", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
    }
}

@Composable
private fun LibraryCard(zone: StudyZone) {
    val colors = MaterialTheme.colorScheme
    var expanded by remember(zone.id) { mutableStateOf(false) }
    val tint = if (zone.percent != null) busyColor(zone.percent) else colors.onSurfaceVariant
    Column(
        Modifier
            .fillMaxWidth()
            .zotCard()
            .clickable { expanded = !expanded }
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(zone.name, fontWeight = FontWeight.SemiBold, color = colors.onBackground, modifier = Modifier.weight(1f))
            StatusPill(zone.isOpen)
            Icon(
                if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore,
                contentDescription = null,
                tint = colors.onSurfaceVariant,
            )
        }
        if (zone.isOpen && zone.percent != null) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("${zone.percent}%", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = tint)
                Text(busyLabel(zone.percent), fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
            }
            OccupancyBar(zone.percent, tint)
        }
        zone.hours?.let {
            Text(it, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
        }
        if (expanded) {
            if (zone.isOpen && zone.floors.isNotEmpty()) {
                zone.floors.forEach { floor ->
                    Row(
                        Modifier.fillMaxWidth().padding(top = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(floor.name, fontWeight = FontWeight.Medium, color = colors.onBackground)
                        Text(floor.percent?.let { "$it%" } ?: "No data", fontWeight = FontWeight.SemiBold, color = colors.onSurfaceVariant)
                    }
                }
            } else if (!zone.isOpen) {
                Text("Floors hide while this library is closed.", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
            } else {
                Text("No floor breakdown right now.", fontWeight = FontWeight.Medium, color = colors.onSurfaceVariant)
            }
        }
    }
}
