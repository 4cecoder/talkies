package com.talkies.android

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Material 3 palette that keeps Talkies' original neon field-console identity. */
private val TalkiesColors = darkColorScheme(
    primary = Color(0xFF6FFFE9),
    onPrimary = Color(0xFF061713),
    primaryContainer = Color(0xFF123B38),
    onPrimaryContainer = Color(0xFFB9FFF4),
    secondary = Color(0xFFB69CFF),
    onSecondary = Color(0xFF21163E),
    secondaryContainer = Color(0xFF35265A),
    onSecondaryContainer = Color(0xFFE1D6FF),
    tertiary = Color(0xFFFFB86B),
    background = Color(0xFF070B14),
    surface = Color(0xFF101827),
    surfaceVariant = Color(0xFF19243A),
    onBackground = Color(0xFFD9E7FF),
    onSurface = Color(0xFFD9E7FF),
    onSurfaceVariant = Color(0xFFA9B9D4),
    error = Color(0xFFFF718B),
)

@Composable
internal fun TalkiesTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = TalkiesColors, content = content)
}
