package com.atharvgupta.anteats.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.atharvgupta.anteats.data.DiningLocation
import com.atharvgupta.anteats.data.DiningLogic
import com.atharvgupta.anteats.data.DiningMenu
import com.atharvgupta.anteats.data.DiningRepository
import com.atharvgupta.anteats.data.DishFeedbackLogic
import com.atharvgupta.anteats.data.DishReport
import com.atharvgupta.anteats.data.DishReportFeed
import com.atharvgupta.anteats.data.DishReportLogic
import com.atharvgupta.anteats.data.EatPostedDay
import com.atharvgupta.anteats.data.EatPostedDays
import com.atharvgupta.anteats.data.HallDirectory
import com.atharvgupta.anteats.data.MenuItem
import com.atharvgupta.anteats.data.PacificTime
import com.atharvgupta.anteats.data.PlateStore
import com.atharvgupta.anteats.BuildConfig
import com.atharvgupta.anteats.data.PreferencesStore
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
    val showFilters: Boolean = false,
    val screenshotReady: Boolean = false,
    val dishReports: List<DishReport> = emptyList(),
)

class EatViewModel(
    private val repository: DiningRepository = DiningRepository(),
    val plate: PlateStore,
    val prefs: PreferencesStore,
    private val reportFeed: DishReportFeed = DishReportFeed(
        token = BuildConfig.REVIEWS_TOKEN,
    ),
) : ViewModel() {
    private val _state = MutableStateFlow(EatUiState(dishReports = prefs.cachedDishReports()))
    val state: StateFlow<EatUiState> = _state.asStateFlow()
    private var menuJob: Job? = null

    init {
        refresh()
        loadReports()
    }

    fun isReportedMissing(item: MenuItem): Boolean {
        val snapshot = _state.value
        return DishReportLogic.isReportedMissing(
            snapshot.dishReports,
            snapshot.selectedDate,
            snapshot.selectedHall,
            snapshot.selectedPeriod,
            item.id,
            item.name,
        )
    }

    fun myReport(item: MenuItem): DishReport? {
        val snapshot = _state.value
        return DishReportLogic.lookup(
            snapshot.dishReports,
            snapshot.selectedDate,
            snapshot.selectedHall,
            snapshot.selectedPeriod,
            item.id,
            item.name,
            prefs.reviewerID,
        )
    }

    fun submitReport(item: MenuItem, reason: String) {
        viewModelScope.launch {
            val snapshot = _state.value
            val optimistic = DishReportLogic.upsert(
                existing = snapshot.dishReports,
                date = snapshot.selectedDate,
                hall = snapshot.selectedHall,
                meal = snapshot.selectedPeriod,
                dishID = item.id,
                dishName = item.name,
                reason = reason,
                authorID = prefs.reviewerID,
                updatedAt = java.time.Instant.now().toString(),
            )
            _state.update { it.copy(dishReports = optimistic) }
            prefs.saveDishReports(optimistic)
            val next = reportFeed.submit(
                date = snapshot.selectedDate,
                hall = snapshot.selectedHall,
                meal = snapshot.selectedPeriod,
                dishID = item.id,
                dishName = item.name,
                reason = reason,
                authorID = prefs.reviewerID,
                existing = optimistic,
            )
            val merged = DishReportFeed.merge(optimistic, next)
            _state.update { it.copy(dishReports = merged) }
            prefs.saveDishReports(merged)
        }
    }

    fun submitFeedback(item: MenuItem, text: String) {
        viewModelScope.launch {
            val snapshot = _state.value
            prefs.markFeedbackNoted(
                DishReportLogic.listingKey(
                    snapshot.selectedDate,
                    snapshot.selectedHall,
                    snapshot.selectedPeriod,
                    item.id,
                    item.name,
                ),
            )
            val clipped = DishFeedbackLogic.clipped(text)
            if (clipped.isEmpty()) return@launch
            val now = System.currentTimeMillis()
            val history = prefs.feedbackHistoryMs()
            if (!DishFeedbackLogic.canSend(history, now)) return@launch
            prefs.saveFeedbackHistoryMs(DishFeedbackLogic.recordedHistory(history, now))
            reportFeed.submitFeedback(
                date = snapshot.selectedDate,
                hall = snapshot.selectedHall,
                meal = snapshot.selectedPeriod,
                dishID = item.id,
                dishName = item.name,
                text = clipped,
                authorID = prefs.reviewerID,
            )
        }
    }

    private fun loadReports() {
        viewModelScope.launch {
            val remote = runCatching { reportFeed.fetch() }.getOrDefault(emptyList())
            val merged = DishReportFeed.merge(prefs.cachedDishReports(), remote)
            _state.update { it.copy(dishReports = merged) }
            prefs.saveDishReports(merged)
        }
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
                val period = DiningLogic.autoPill(
                    hall?.periods.orEmpty(),
                    PacificTime.nowMinutes(),
                    hall?.availablePeriods.orEmpty(),
                    _state.value.selectedDate,
                )
                    .takeIf { it in DiningLogic.visibleMealPills(hall?.availablePeriods.orEmpty(), _state.value.selectedDate) }
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
        _state.update { it.copy(selectedHall = id, selectedDish = null, menu = null) }
        loadMenu()
    }

    fun selectPeriod(period: String) {
        if (period == _state.value.selectedPeriod) return
        _state.update { it.copy(selectedPeriod = period, selectedDish = null, menu = null) }
        loadMenu()
    }

    fun selectDate(iso: String) {
        if (iso == _state.value.selectedDate) return
        val hall = _state.value.halls.firstOrNull { it.id == _state.value.selectedHall }
        val available = hall?.availablePeriods.orEmpty()
        val pills = DiningLogic.visibleMealPills(available, iso)
        val current = _state.value.selectedPeriod
        val period = current.takeIf { it in pills }
            ?: DiningLogic.autoPill(hall?.periods.orEmpty(), PacificTime.nowMinutes(), available, iso)
                .takeIf { it in pills }
            ?: pills.firstOrNull()
            ?: DiningLogic.clockPill(PacificTime.nowMinutes())
        _state.update {
            it.copy(selectedDate = iso, selectedPeriod = period, selectedDish = null, menu = null)
        }
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

    fun showFilters(show: Boolean) {
        _state.update { it.copy(showFilters = show) }
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
                "filters" -> showFilters(true)
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

class EatViewModelFactory(
    private val plate: PlateStore,
    private val prefs: PreferencesStore,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        EatViewModel(plate = plate, prefs = prefs) as T
}
