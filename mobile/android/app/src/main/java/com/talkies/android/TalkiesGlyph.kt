package com.talkies.android

import androidx.compose.foundation.Canvas
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

internal enum class TalkiesGlyphKind { SERVER, TERMINAL, KEYBOARD, MICROPHONE, HIDE }

/** Small, dependency-free line icons drawn for the exact control they label. */
@androidx.compose.runtime.Composable
internal fun TalkiesGlyph(kind: TalkiesGlyphKind, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.075f
        val w = size.width
        val h = size.height
        when (kind) {
            TalkiesGlyphKind.SERVER -> {
                drawRoundRect(color, Offset(w * .16f, h * .16f), Size(w * .68f, h * .28f), androidx.compose.ui.geometry.CornerRadius(stroke * 2), style = Stroke(stroke))
                drawRoundRect(color, Offset(w * .16f, h * .56f), Size(w * .68f, h * .28f), androidx.compose.ui.geometry.CornerRadius(stroke * 2), style = Stroke(stroke))
                drawCircle(color, stroke * 1.3f, Offset(w * .28f, h * .30f))
                drawCircle(color, stroke * 1.3f, Offset(w * .28f, h * .70f))
                drawLine(color.copy(alpha = .7f), Offset(w * .40f, h * .30f), Offset(w * .72f, h * .30f), stroke)
                drawLine(color.copy(alpha = .7f), Offset(w * .40f, h * .70f), Offset(w * .72f, h * .70f), stroke)
            }
            TalkiesGlyphKind.TERMINAL -> {
                drawRoundRect(color, Offset(w * .10f, h * .14f), Size(w * .80f, h * .72f), androidx.compose.ui.geometry.CornerRadius(stroke * 2), style = Stroke(stroke))
                drawLine(color, Offset(w * .25f, h * .40f), Offset(w * .40f, h * .50f), stroke, cap = StrokeCap.Round)
                drawLine(color, Offset(w * .40f, h * .50f), Offset(w * .25f, h * .60f), stroke, cap = StrokeCap.Round)
                drawLine(color, Offset(w * .49f, h * .61f), Offset(w * .67f, h * .61f), stroke, cap = StrokeCap.Round)
            }
            TalkiesGlyphKind.KEYBOARD -> {
                drawRoundRect(color, Offset(w * .08f, h * .22f), Size(w * .84f, h * .56f), androidx.compose.ui.geometry.CornerRadius(stroke * 2), style = Stroke(stroke))
                for (row in 0..1) for (column in 0..4) {
                    drawRoundRect(color.copy(alpha = .88f), Offset(w * (.18f + column * .14f), h * (.34f + row * .18f)), Size(w * .07f, h * .08f), androidx.compose.ui.geometry.CornerRadius(stroke), style = Stroke(stroke * .8f))
                }
                drawLine(color, Offset(w * .34f, h * .67f), Offset(w * .66f, h * .67f), stroke, cap = StrokeCap.Round)
            }
            TalkiesGlyphKind.MICROPHONE -> {
                drawRoundRect(color, Offset(w * .37f, h * .12f), Size(w * .26f, h * .48f), androidx.compose.ui.geometry.CornerRadius(w * .14f))
                drawArc(color, 0f, 180f, false, Offset(w * .22f, h * .31f), Size(w * .56f, h * .48f), style = Stroke(stroke, cap = StrokeCap.Round))
                drawLine(color, Offset(w * .50f, h * .79f), Offset(w * .50f, h * .91f), stroke, cap = StrokeCap.Round)
                drawLine(color, Offset(w * .36f, h * .91f), Offset(w * .64f, h * .91f), stroke, cap = StrokeCap.Round)
            }
            TalkiesGlyphKind.HIDE -> {
                drawLine(color, Offset(w * .22f, h * .36f), Offset(w * .50f, h * .64f), stroke, cap = StrokeCap.Round)
                drawLine(color, Offset(w * .50f, h * .64f), Offset(w * .78f, h * .36f), stroke, cap = StrokeCap.Round)
            }
        }
    }
}
