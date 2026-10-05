package com.atharvgupta.anteats.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class DietChipColorTest {
    @Test
    fun veganIsDarkGreenVegetarianIsLightGreen() {
        val vegan = dietChipLook("Vegan", Sage, dark = false)
        val vegetarian = dietChipLook("Vegetarian", Sage, dark = false)
        assertEquals(VeganFillLight, vegan.background)
        assertEquals(VeganLabel, vegan.foreground)
        assertEquals(VegetarianFillLight, vegetarian.background)
        assertEquals(VegetarianLabel, vegetarian.foreground)
        assertNotEquals(vegan.background, vegetarian.background)
    }

    @Test
    fun otherDietTagsKeepWashStyle() {
        val halal = dietChipLook("Halal", Slate, dark = false)
        assertEquals(0.10f, halal.background.alpha, 0.02f)
        assertNotEquals(VeganFillLight, halal.background)
        assertNotEquals(VegetarianFillLight, halal.background)
        val kosher = dietChipLook("Kosher", Plum, dark = false)
        assertEquals(0.10f, kosher.background.alpha, 0.02f)
        val gf = dietChipLook("Gluten-Free", Ochre, dark = false)
        assertEquals(0.10f, gf.background.alpha, 0.02f)
    }
}
