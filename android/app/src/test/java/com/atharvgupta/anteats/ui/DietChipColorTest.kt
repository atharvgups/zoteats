package com.atharvgupta.anteats.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DietChipColorTest {
    @Test
    fun veganIsDeeperSageVegetarianIsPalerGreen() {
        val vegan = dietChipLook("Vegan", Sage, dark = false)
        val vegetarian = dietChipLook("Vegetarian", Sage, dark = false)
        assertEquals(VeganFillLight, vegan.background)
        assertEquals(VeganLabelLight, vegan.foreground)
        assertEquals(VegetarianFillLight, vegetarian.background)
        assertEquals(VegetarianLabelLight, vegetarian.foreground)
        assertNotEquals(vegan.background, vegetarian.background)
        assertTrue(luminance(vegan.background) < luminance(vegetarian.background))
    }

    @Test
    fun dietRowUsesOpaquePastelsNotWashes() {
        for (tag in listOf("Vegan", "Vegetarian", "Plant Forward", "Halal", "Kosher", "Gluten-Free")) {
            val look = dietChipLook(tag, Slate, dark = false)
            assertEquals(1.0f, look.background.alpha, 0.001f)
            assertEquals(1.0f, look.foreground.alpha, 0.001f)
        }
    }

    @Test
    fun allergensKeepWashStyle() {
        val allergen = dietChipLook("Peanuts", Terracotta, dark = false)
        assertEquals(0.10f, allergen.background.alpha, 0.02f)
    }

    private fun luminance(color: androidx.compose.ui.graphics.Color): Float {
        fun lin(c: Float): Float = if (c <= 0.04045f) c / 12.92f else Math.pow(((c + 0.055) / 1.055).toDouble(), 2.4).toFloat()
        return 0.2126f * lin(color.red) + 0.7152f * lin(color.green) + 0.0722f * lin(color.blue)
    }
}
