package com.talkies.android

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import java.text.DateFormat
import java.util.Date
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val HISTORY_PAGE_SIZE = 50

/** Saved dictations, newest first. All store calls run on the IO dispatcher. */
@Composable
internal fun HistoryScreen(store: TranscriptHistoryStore, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    var records by remember { mutableStateOf(emptyList<TranscriptRecord>()) }
    var next by remember { mutableStateOf<TranscriptPageCursor?>(null) }
    var loading by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var confirmClear by remember { mutableStateOf(false) }
    // Bumped by every reload so a slow page for an older query cannot replace newer results.
    var generation by remember { mutableStateOf(0) }

    fun load(reset: Boolean) {
        val requestGeneration = if (reset) ++generation else generation
        val after = if (reset) null else next
        loading = true
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching { store.page(query, after, HISTORY_PAGE_SIZE) }
            }
            if (requestGeneration != generation) return@launch
            loading = false
            result.onSuccess { page ->
                records = if (reset) page.records else records + page.records
                next = page.next
                status = HistoryText.summary(records.size, page.next != null, query)
            }.onFailure { status = "Could not read transcript history." }
        }
    }

    LaunchedEffect(query) {
        if (query.isNotEmpty()) delay(250)
        load(reset = true)
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = onBack) { Text("Back") }
            OutlinedButton(enabled = records.isNotEmpty(), onClick = { confirmClear = true }) { Text("Clear all") }
        }
        Text("History", style = MaterialTheme.typography.headlineLarge)
        Text(
            "Saved on this device only. Turn off \"Save transcript history\" to stop saving new dictations.",
            style = MaterialTheme.typography.bodySmall
        )
        TextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Search history") }
        )
        if (status.isNotEmpty()) Text(status, style = MaterialTheme.typography.bodyMedium)
        LazyColumn(
            modifier = Modifier.fillMaxWidth().weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(records, key = { it.id }) { record ->
                HistoryItem(
                    record = record,
                    onCopy = {
                        copyText(context, record.text)
                        status = "Transcript copied."
                    },
                    onDelete = {
                        scope.launch {
                            val deleted = withContext(Dispatchers.IO) {
                                runCatching { store.delete(record.id) }.getOrDefault(false)
                            }
                            if (deleted) {
                                records = records.filterNot { it.id == record.id }
                                status = "Transcript deleted."
                            } else {
                                status = "Could not delete the transcript."
                            }
                        }
                    }
                )
            }
            if (next != null) {
                item {
                    OutlinedButton(enabled = !loading, onClick = { load(reset = false) }) { Text("Load more") }
                }
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("Clear transcript history?") },
            text = { Text("This permanently deletes every saved transcript on this device.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmClear = false
                    clearHistory(scope, store) { cleared ->
                        if (cleared) {
                            generation++
                            records = emptyList()
                            next = null
                            loading = false
                        }
                        status = HistoryText.cleared(cleared)
                    }
                }) { Text("Clear all") }
            },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text("Cancel") } }
        )
    }
}

@Composable
private fun HistoryItem(record: TranscriptRecord, onCopy: () -> Unit, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                HistoryText.details(
                    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                        .format(Date(record.createdAtMillis)),
                    record
                ),
                style = MaterialTheme.typography.labelMedium
            )
            Text(record.text, style = MaterialTheme.typography.bodyLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onCopy) { Text("Copy") }
                TextButton(onClick = onDelete) { Text("Delete") }
            }
        }
    }
}

private fun copyText(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Talkies transcript", text))
}

/** Clears history off the main thread and reports success on the caller's dispatcher. */
internal fun clearHistory(
    scope: kotlinx.coroutines.CoroutineScope,
    store: TranscriptHistoryStore,
    onDone: (Boolean) -> Unit,
) {
    scope.launch {
        val cleared = withContext(Dispatchers.IO) { runCatching { store.clear() }.isSuccess }
        onDone(cleared)
    }
}

/** User-facing history text. Kept free of Android types so it is unit-tested. */
internal object HistoryText {
    fun summary(count: Int, hasMore: Boolean, query: String): String = when {
        count == 0 && query.isNotBlank() -> "No saved transcripts match \"${query.trim()}\"."
        count == 0 -> "No saved transcripts yet."
        hasMore -> "Showing the newest $count transcripts."
        count == 1 -> "1 saved transcript."
        else -> "$count saved transcripts."
    }

    fun details(formattedDate: String, record: TranscriptRecord): String = buildList {
        add(formattedDate)
        record.runtime?.let {
            add(
                when (it) {
                    TranscriptRuntime.PHONON -> SpeechEngine.PHONON_2.label
                    TranscriptRuntime.WHISPER -> SpeechEngine.WHISPER_TINY.label
                }
            )
        }
        record.durationMillis?.let { add(duration(it)) }
        if (record.rawText != null) add("cleaned")
    }.joinToString(" · ")

    fun duration(millis: Long): String {
        val seconds = (millis + 500) / 1000
        return if (seconds < 60) "${seconds}s" else "${seconds / 60}m ${seconds % 60}s"
    }

    fun cleared(success: Boolean): String =
        if (success) "Transcript history cleared." else "Could not clear transcript history."
}
