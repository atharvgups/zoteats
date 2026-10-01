package com.atharvgupta.anteats.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Ink = Color(0xFF1C1B18)
val InkOnDark = Color(0xFFF5F5F5)
val CanvasLight = Color(0xFFFFFFFF)
val CanvasDark = Color(0xFF000000)
val CardLight = Color(0xFFFFFFFF)
val CardDark = Color(0xFF1A1A1A)
val HairlineLight = Color(0x1A1C1B18)
val HairlineDark = Color(0x1AFFFFFF)
val OpenGreen = Color(0xFF01A858)
val Gold = Color(0xFFA87A00)
val GoldDark = Color(0xFFFFD200)
val Sage = Color(0xFF4A7C59)

private val LightColors = lightColorScheme(
    primary = Ink,
    onPrimary = CanvasLight,
    background = CanvasLight,
    onBackground = Ink,
    surface = CardLight,
    onSurface = Ink,
    surfaceVariant = Color(0xFFF4F4F4),
    onSurfaceVariant = Color(0xFF5C5C5C),
    outline = HairlineLight,
    secondary = Gold,
    tertiary = OpenGreen,
)

private val DarkColors = darkColorScheme(
    primary = InkOnDark,
    onPrimary = CanvasDark,
    background = CanvasDark,
    onBackground = InkOnDark,
    surface = CardDark,
    onSurface = InkOnDark,
    surfaceVariant = Color(0xFF222222),
    onSurfaceVariant = Color(0xFFBDBDBD),
    outline = HairlineDark,
    secondary = GoldDark,
    tertiary = OpenGreen,
)

@Composable
fun AnteatsTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
