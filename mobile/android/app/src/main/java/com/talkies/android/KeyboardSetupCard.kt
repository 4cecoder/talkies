package com.talkies.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
internal fun KeyboardSetupCard(
    enabled: Boolean,
    selected: Boolean,
    microphoneAllowed: Boolean,
    onEnable: () -> Unit,
    onSelect: () -> Unit,
    onAllowMicrophone: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                TalkiesGlyph(TalkiesGlyphKind.KEYBOARD, MaterialTheme.colorScheme.primary, Modifier.size(40.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("VOICE, WHERE YOU TYPE", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    Text("Make Talkies your keyboard", style = MaterialTheme.typography.titleLarge)
                }
                Text(if (selected) "READY" else "SETUP", style = MaterialTheme.typography.labelSmall, color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.tertiary)
            }
            Text(
                "Dictate directly into messages, notes, and terminals. Your audio is transcribed on this device.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            SetupStep(
                number = "01",
                title = "Enable Talkies",
                detail = if (enabled) "Keyboard permission is enabled" else "Turn on Talkies voice typing in Android settings",
                done = enabled,
                action = if (enabled) "Enabled" else "Open settings",
                onClick = onEnable,
            )
            SetupStep(
                number = "02",
                title = "Choose Talkies",
                detail = if (selected) "Ready in any text field" else if (enabled) "Switch to Talkies from the keyboard picker" else "Enable Talkies first",
                done = selected,
                action = if (selected) "Selected" else "Choose keyboard",
                enabled = enabled && !selected,
                onClick = onSelect,
            )
            SetupStep(
                number = "03",
                title = "Allow voice input",
                detail = if (microphoneAllowed) "Microphone is ready for Talkies" else "Grant access once to dictate from any text field",
                done = microphoneAllowed,
                action = if (microphoneAllowed) "Allowed" else "Allow mic",
                enabled = selected && !microphoneAllowed,
                onClick = onAllowMicrophone,
            )
            if (selected) {
                Text("Tip: use the keyboard switcher to return to your usual keyboard at any time.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SetupStep(
    number: String,
    title: String,
    detail: String,
    done: Boolean,
    action: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            if (done) "✓" else number,
            modifier = Modifier.clip(CircleShape).background(if (done) MaterialTheme.colorScheme.primaryContainer else Color(0xFF273653)).padding(horizontal = 10.dp, vertical = 7.dp),
            style = MaterialTheme.typography.labelMedium,
            color = if (done) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.primary,
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (done) {
            Text("DONE", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
        } else if (number == "01") {
            Button(enabled = enabled, onClick = onClick) { Text(action) }
        } else {
            OutlinedButton(enabled = enabled, onClick = onClick) { Text(action) }
        }
    }
}
