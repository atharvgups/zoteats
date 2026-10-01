package com.atharvgupta.anteats.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class PlateStore {
    private val _entries = MutableStateFlow<List<PlateEntry>>(emptyList())
    val entries: StateFlow<List<PlateEntry>> = _entries.asStateFlow()

    val isEmpty: Boolean get() = _entries.value.isEmpty()
    val servingCount: Int get() = _entries.value.sumOf { it.quantity }
    val totalCalories: Int get() = _entries.value.sumOf { it.lineCalories }
    val totalProteinG: Int get() = _entries.value.sumOf { it.lineProteinG }.let { Math.round(it).toInt() }

    fun quantity(dishName: String): Int =
        _entries.value.firstOrNull { it.dish.name.equals(dishName, true) }?.quantity ?: 0

    fun isOnPlate(dishName: String): Boolean = quantity(dishName) > 0

    fun add(dish: MenuItem) {
        _entries.update { current ->
            val index = current.indexOfFirst { it.dish.name.equals(dish.name, true) }
            if (index < 0) current + PlateEntry(dish, 1)
            else current.toMutableList().also {
                it[index] = it[index].copy(quantity = it[index].quantity + 1)
            }
        }
    }

    fun setQuantity(dishName: String, quantity: Int) {
        _entries.update { current ->
            if (quantity <= 0) current.filterNot { it.dish.name.equals(dishName, true) }
            else current.map {
                if (it.dish.name.equals(dishName, true)) it.copy(quantity = quantity) else it
            }
        }
    }

    fun clear() {
        _entries.value = emptyList()
    }
}
