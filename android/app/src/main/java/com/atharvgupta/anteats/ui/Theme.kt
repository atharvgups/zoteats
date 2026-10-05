package com.atharvgupta.anteats.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val InkLight = Color(0xFF1C1B18)
val InkDark = Color(0xFFF5F5F4)
val CanvasLight = Color(0xFFFFFFFF)
val CanvasDark = Color(0xFF000000)
val CardLight = Color(0xFFFFFFFF)
val CardDark = Color(0xFF2C2C2E)
val HairlineLight = Color(0x1A1C1B18)
val HairlineDark = Color(0x1AFFFFFF)
val SelectWash = Color(0x0F1C1B18)
val AccentLight = Color(0xFFA87A00)
val AccentDark = Color(0xFFFFD200)
val OpenGreen = Color(0xFF01A858)
val BusyOrange = Color(0xFFD68C20)
val CrowdedRed = Color(0xFFC43E4A)
val Sage = Color(0xFF448365)
val Eucalyptus = Color(0xFF599484)
val VeganFillLight = Color(0xFF14532D)
val VeganFillDark = Color(0xFF166534)
val VeganLabel = Color(0xFFECFDF5)
val VegetarianFillLight = Color(0xFFBBF7D0)
val VegetarianFillDark = Color(0xFF86EFAC)
val VegetarianLabel = Color(0xFF14532D)
val Slate = Color(0xFF54769F)
val Plum = Color(0xFF84689C)
val Ochre = Color(0xFF9E7C4C)
val Clay = Color(0xFF936E5A)
val Terracotta = Color(0xFFB26A57)
val FavoritePink = Color(0xFFFF2D55)
val UciBlue = Color(0xFF0064A4)

val HallRadius = 20.dp
val CardRadius = 16.dp
val InnerRadius = 10.dp
val ChipRadius = 999.dp
val HallTileHeight = 88.dp
val HallNameSize = 26.sp
val HallStatusSize = 12.sp
val PillTextSize = 15.sp
val HeroSize = 34.sp
val SheetHeroSize = 26.sp
val SectionSize = 18.sp

fun dietColor(tag: String, dark: Boolean = false): Color = when (tag.lowercase()) {
    "vegan" -> if (dark) VeganFillDark else VeganFillLight
    "vegetarian" -> if (dark) VegetarianFillDark else VegetarianFillLight
    "halal" -> Slate
    "kosher" -> Plum
    "gluten-free", "gluten free" -> Ochre
    "organic" -> Clay
    else -> Slate
}

data class ChipLook(val foreground: Color, val background: Color)

fun dietChipLook(tag: String, fallback: Color, dark: Boolean): ChipLook = when (tag.lowercase()) {
    "vegan" -> ChipLook(VeganLabel, if (dark) VeganFillDark else VeganFillLight)
    "vegetarian" -> ChipLook(VegetarianLabel, if (dark) VegetarianFillDark else VegetarianFillLight)
    else -> ChipLook(fallback, fallback.copy(alpha = 0.10f))
}

@Composable
fun AnteatsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) {
        darkColorScheme(
            primary = InkDark,
            onPrimary = CanvasDark,
            background = CanvasDark,
            onBackground = InkDark,
            surface = CardDark,
            onSurface = InkDark,
            surfaceVariant = Color(0xFF3A3A3C),
            onSurfaceVariant = Color(0xFFAEAEB2),
            outline = HairlineDark,
            secondary = AccentDark,
            tertiary = OpenGreen,
        )
    } else {
        lightColorScheme(
            primary = InkLight,
            onPrimary = CanvasLight,
            background = CanvasLight,
            onBackground = InkLight,
            surface = CardLight,
            onSurface = InkLight,
            surfaceVariant = Color(0xFFF4F4F4),
            onSurfaceVariant = Color(0xFF6E6E73),
            outline = HairlineLight,
            secondary = AccentLight,
            tertiary = OpenGreen,
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}

@Composable
fun accentGold(dark: Boolean = isSystemInDarkTheme()): Color = if (dark) AccentDark else AccentLight
