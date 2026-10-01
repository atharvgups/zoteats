package com.atharvgupta.anteats.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.atharvgupta.anteats.data.DiningLocation
import com.atharvgupta.anteats.data.DiningLogic
import com.atharvgupta.anteats.data.DiningMenu
import com.atharvgupta.anteats.data.DiningRepository
import com.atharvgupta.anteats.data.EatPostedDay
import com.atharvgupta.anteats.data.EatPostedDays
import com.atharvgupta.anteats.data.HallDirectory
import com.atharvgupta.anteats.data.MenuItem
import com.atharvgupta.anteats.data.PacificTime
import com.atharvgupta.anteats.data.PlateStore
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EatUiState(
    val halls: List<DiningLocation> = emptyList(),
    val selectedHall: String = HallDirectory.ANTEATERY,
    val selectedPeriod: String = DiningLogic.clockPill(PacificTime.nowMinutes()),
    val selectedDate: String = PacificTime.todayISO(),
    val days: List<EatPostedDay> = emptyList(),
    val menu: DiningMenu? = null,
    val loading: Boolean = true,
    val error: String? = null,
    val selectedDish: MenuItem? = null,
    val showPlate: Boolean = false,
    val screenshotReady: Boolean = false,
)

class EatViewModel(
    private val repository: DiningRepository = DiningRepository(),
    val plate: PlateStore = PlateStore(),
) : ViewModel() {
    private val _state = MutableStateFlow(EatUiState())
    val state: StateFlow<EatUiState> = _state.asStateFlow()
    private var menuJob: Job? = null

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null, screenshotReady = false) }
            runCatching {
                val halls = repository.locations()
                val range = repository.publishedDateRange()
                val today = PacificTime.todayISO()
                val days = EatPostedDays.visible(today, latest = range?.latest)
                val selectedHall = _state.value.selectedHall.takeIf { id -> halls.any { it.id == id } }
                    ?: halls.firstOrNull()?.id
                    ?: HallDirectory.ANTEATERY
                val hall = halls.firstOrNull { it.id == selectedHall }
                val period = DiningLogic.autoPill(hall?.periods.orEmpty(), PacificTime.nowMinutes())
                    .takeIf { it in DiningLogic.mealSelectorPills }
                    ?: DiningLogic.clockPill(PacificTime.nowMinutes())
                _state.update {
                    it.copy(
                        halls = halls,
                        selectedHall = selectedHall,
                        selectedPeriod = period,
                        days = days,
                        selectedDate = it.selectedDate.takeIf { date -> days.any { day -> day.isoDate == date } } ?: today,
                    )
                }
                loadMenu()
            }.onFailure {
                _state.update {
                    it.copy(
                        loading = false,
                        error = "Could not load menus. Check your connection and try again.",
                        screenshotReady = true,
                    )
                }
            }
        }
    }

    fun selectHall(id: String) {
        if (id == _state.value.selectedHall) return
        _state.update { it.copy(selectedHall = id, selectedDish = null) }
        loadMenu()
    }

    fun selectPeriod(period: String) {
        if (period == _state.value.selectedPeriod) return
        _state.update { it.copy(selectedPeriod = period, selectedDish = null) }
        loadMenu()
    }

    fun selectDate(iso: String) {
        if (iso == _state.value.selectedDate) return
        _state.update { it.copy(selectedDate = iso, selectedDish = null) }
        loadMenu()
    }

    fun openDish(item: MenuItem) {
        _state.update { it.copy(selectedDish = item) }
    }

    fun closeDish() {
        _state.update { it.copy(selectedDish = null) }
    }

    fun showPlate(show: Boolean) {
        _state.update { it.copy(showPlate = show) }
    }

    fun applyScreenshot(mode: String?) {
        viewModelScope.launch {
            val current = _state.value
            val firstDish = current.menu?.stations?.flatMap { it.items }?.firstOrNull()
            when (mode) {
                "dish" -> if (firstDish != null) openDish(firstDish)
                "plate" -> {
                    firstDish?.let { plate.add(it) }
                    showPlate(true)
                }
            }
            _state.update { it.copy(screenshotReady = true) }
        }
    }

    private fun loadMenu() {
        menuJob?.cancel()
        menuJob = viewModelScope.launch {
            val snapshot = _state.value
            _state.update { it.copy(loading = true, error = null, screenshotReady = false) }
            runCatching {
                repository.menu(snapshot.selectedHall, snapshot.selectedPeriod, snapshot.selectedDate)
            }.onSuccess { menu ->
                _state.update { it.copy(menu = menu, loading = false, screenshotReady = true) }
            }.onFailure {
                _state.update {
                    it.copy(
                        loading = false,
                        error = "Could not load this meal. Try another hall or day.",
                        screenshotReady = true,
                    )
                }
            }
        }
    }
}
