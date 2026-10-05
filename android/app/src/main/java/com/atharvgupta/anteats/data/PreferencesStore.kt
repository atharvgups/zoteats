package com.atharvgupta.anteats.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import org.json.JSONObject

enum class Appearance { System, Light, Dark }

class PreferencesStore(context: Context) {
    private val prefs = context.getSharedPreferences("anteats", Context.MODE_PRIVATE)
    private val _favorites = MutableStateFlow(loadSet("favorites"))
    private val _reviews = MutableStateFlow(loadReviews())
    private val _diets = MutableStateFlow(loadSet("diets"))
    private val _allergens = MutableStateFlow(loadSet("allergens"))
    private val _appearance = MutableStateFlow(
        Appearance.entries.firstOrNull { it.name == prefs.getString("appearance", "System") } ?: Appearance.System,
    )
    private val _campusFavorites = MutableStateFlow(loadSet("campusFavorites"))
    private val _notifications = MutableStateFlow(prefs.getBoolean("notifications", false))

    val favorites: StateFlow<Set<String>> = _favorites.asStateFlow()
    val reviews: StateFlow<Map<String, Int>> = _reviews.asStateFlow()
    val diets: StateFlow<Set<String>> = _diets.asStateFlow()
    val allergens: StateFlow<Set<String>> = _allergens.asStateFlow()
    val appearance: StateFlow<Appearance> = _appearance.asStateFlow()
    val campusFavorites: StateFlow<Set<String>> = _campusFavorites.asStateFlow()
    val notifications: StateFlow<Boolean> = _notifications.asStateFlow()

    val hasFilters: Boolean get() = _diets.value.isNotEmpty() || _allergens.value.isNotEmpty()

    fun isFavorite(name: String) = _favorites.value.any { it.equals(name, true) }
    fun stars(name: String) = _reviews.value.entries.firstOrNull { it.key.equals(name, true) }?.value ?: 0

    fun toggleFavorite(name: String) {
        _favorites.update { cur ->
            if (cur.any { it.equals(name, true) }) cur.filterNot { it.equals(name, true) }.toSet()
            else cur + name
        }
        prefs.edit().putStringSet("favorites", _favorites.value).apply()
    }

    fun setStars(name: String, stars: Int) {
        _reviews.update { it + (name to stars.coerceIn(0, 5)) }
        val json = JSONObject()
        _reviews.value.forEach { json.put(it.key, it.value) }
        prefs.edit().putString("reviews", json.toString()).apply()
    }

    fun toggleDiet(tag: String) {
        _diets.update { if (tag in it) it - tag else it + tag }
        prefs.edit().putStringSet("diets", _diets.value).apply()
    }

    fun toggleAllergen(tag: String) {
        _allergens.update { if (tag in it) it - tag else it + tag }
        prefs.edit().putStringSet("allergens", _allergens.value).apply()
    }

    fun clearFilters() {
        _diets.value = emptySet()
        _allergens.value = emptySet()
        prefs.edit().remove("diets").remove("allergens").apply()
    }

    fun setAppearance(value: Appearance) {
        _appearance.value = value
        prefs.edit().putString("appearance", value.name).apply()
    }

    fun isCampusFavorite(id: String) = id in _campusFavorites.value

    fun toggleCampusFavorite(id: String) {
        _campusFavorites.update { if (id in it) it - id else it + id }
        prefs.edit().putStringSet("campusFavorites", _campusFavorites.value).apply()
    }

    fun setNotifications(enabled: Boolean) {
        _notifications.value = enabled
        prefs.edit().putBoolean("notifications", enabled).apply()
    }

    fun matches(item: MenuItem): Boolean {
        val diets = _diets.value
        val avoids = _allergens.value
        if (diets.isNotEmpty() && diets.any { need -> item.dietaryTags.none { it.equals(need, true) } }) {
            return false
        }
        if (avoids.any { avoid -> item.allergens.any { it.equals(avoid, true) } }) return false
        return true
    }

    private fun loadSet(key: String): Set<String> = prefs.getStringSet(key, emptySet())?.toSet() ?: emptySet()

    private fun loadReviews(): Map<String, Int> {
        val raw = prefs.getString("reviews", "{}") ?: "{}"
        return runCatching {
            val json = JSONObject(raw)
            json.keys().asSequence().associateWith { json.optInt(it) }
        }.getOrDefault(emptyMap())
    }
}
