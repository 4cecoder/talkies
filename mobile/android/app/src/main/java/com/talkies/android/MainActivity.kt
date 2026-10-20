package com.talkies.android

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.view.inputmethod.InputMethodManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@androidx.compose.runtime.Composable
private fun CleanupOptionSelector(
    label: String,
    selected: String,
    options: List<String>,
    enabled: Boolean,
    onSelected: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    androidx.compose.foundation.layout.Box {
        OutlinedButton(enabled = enabled, onClick = { expanded = true }) {
            Text("$label: $selected")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        onSelected(option)
                        expanded = false
                    }
                )
            }
        }
    }
}

internal inline fun <reified T : Enum<T>> enumValueOrDefault(value: String?, default: T): T =
    value?.let { candidate -> enumValues<T>().firstOrNull { it.name == candidate } } ?: default

class MainActivity : ComponentActivity() {
    private lateinit var speechModels: LocalSpeechModels
    private lateinit var cleanupModelStore: S1MiniModelStore
    private lateinit var cleanupCleaner: TranscriptCleaner
    private val audioCapture = OfflineAudioCapture()
    private var transcript by mutableStateOf("")
    private var status by mutableStateOf("Download a local speech model to get started.")
    private var modelReady by mutableStateOf(false)
    private var modelBusy by mutableStateOf(false)
    private var modelProgress by mutableStateOf(0f)
    private var phononReady by mutableStateOf(false)
    private var phononBusy by mutableStateOf(false)
    private var phononProgress by mutableStateOf(0f)
    private var phononSupported by mutableStateOf(true)
    private var enginePreference by mutableStateOf(SpeechEnginePreference.AUTOMATIC)
    private var dictationEngines by mutableStateOf(emptyList<SpeechEngine>())
    private var cleanupModelReady by mutableStateOf(false)
    private var cleanupBusy by mutableStateOf(false)
    private var cleanupProgress by mutableStateOf(0f)
    private var cleanupEnabled by mutableStateOf(false)
    private var cleanupStyle by mutableStateOf(TranscriptStyle.SEMI_FORMAL)
    private var cleanupStructure by mutableStateOf(TranscriptStructure.PROSE)
    private var cleanupContext by mutableStateOf(TranscriptContext.GENERAL)
    private var recording by mutableStateOf(false)
    private var transcribing by mutableStateOf(false)
    private var historyEnabled by mutableStateOf(true)
    private var showHistory by mutableStateOf(false)
    private var showRemoteCompanion by mutableStateOf(false)
    private var confirmClearHistory by mutableStateOf(false)
    private var remoteDictationSink: ((String) -> Unit)? = null
    private var remoteDictationInProgress = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        speechModels = LocalSpeechModels(filesDir)
        cleanupModelStore = S1MiniModelStore(
            File(File(filesDir, "models"), "S1-mini-${S1MiniModelStore.MODEL_REVISION}")
        )
        cleanupCleaner = S1MiniCleaner(cleanupModelStore)
        val preferences = getSharedPreferences(SpeechSettings.PREFERENCES, MODE_PRIVATE)
        enginePreference = SpeechSettings.enginePreference(preferences)
        cleanupEnabled = preferences.getBoolean("s1-mini-enabled", false)
        cleanupStyle = enumValueOrDefault(preferences.getString("s1-mini-style", null), TranscriptStyle.SEMI_FORMAL)
        cleanupStructure = enumValueOrDefault(preferences.getString("s1-mini-structure", null), TranscriptStructure.PROSE)
        cleanupContext = enumValueOrDefault(preferences.getString("s1-mini-context", null), TranscriptContext.GENERAL)
        historyEnabled = TranscriptHistory.isEnabled(preferences)
        setContent {
            MaterialTheme {
                val context = LocalContext.current
                val requestPermission = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission()
                ) { granted ->
                    if (granted) startRecording() else status = "Microphone permission is needed to dictate."
                }
                Surface(modifier = Modifier.fillMaxSize()) {
                    if (showHistory) {
                        HistoryScreen(TranscriptHistory.store(context)) { showHistory = false }
                        return@Surface
                    }
                    if (showRemoteCompanion) {
                        SshCompanionScreen(
                            context = context,
                            onBack = {
                                if (recording) { audioCapture.cancel(); recording = false }
                                remoteDictationSink = null
                                if (!transcribing) remoteDictationInProgress = false
                                showRemoteCompanion = false
                            },
                            onDictate = { sink ->
                                if (dictationEngines.isEmpty() || anyDownloadBusy() || recording || transcribing) {
                                    status = "Finish the current dictation or download a speech model before recording again."
                                    return@SshCompanionScreen
                                }
                                remoteDictationSink = sink
                                remoteDictationInProgress = true
                                startRecording()
                            },
                        )
                        return@Surface
                    }
                    Column(
                        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text("Talkies", style = MaterialTheme.typography.headlineLarge)
                        Text("Private, on-device dictation", style = MaterialTheme.typography.titleMedium)
                        Text(status, style = MaterialTheme.typography.bodyMedium)

                        OutlinedButton(onClick = { showRemoteCompanion = true }) {
                            Text("Remote companion · SSH / Herdr")
                        }

                        Text("Type by voice in any app", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "Enable Talkies voice typing as a keyboard, grant microphone access here, then select Talkies from your keyboard switcher. Dictation and optional S1-mini cleanup run on-device and insert into the focused field.",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedButton(onClick = {
                                startActivity(Intent(android.provider.Settings.ACTION_INPUT_METHOD_SETTINGS))
                            }) { Text("Enable keyboard") }
                            OutlinedButton(onClick = {
                                (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
                                    .showInputMethodPicker()
                            }) { Text("Select keyboard") }
                        }

                        Text("Speech engine", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "Automatic uses Phonon-2 when it is downloaded and falls back to Whisper tiny if " +
                                "Phonon-2 is missing or fails. Both run only on this device.",
                            style = MaterialTheme.typography.bodySmall
                        )
                        CleanupOptionSelector(
                            "Speech engine", enginePreference.label,
                            SpeechEnginePreference.entries.map { it.label },
                            !recording && !transcribing
                        ) { selected ->
                            enginePreference = SpeechEnginePreference.entries.first { it.label == selected }
                            SpeechSettings.setEnginePreference(preferences, enginePreference)
                            refreshModelStatus(updateStatus = true)
                        }

                        Text("Phonon-2 (English, most accurate)", style = MaterialTheme.typography.titleSmall)
                        Text(
                            "Download size: ${SpeechStatusText.PHONON_DOWNLOAD_SIZE}. A large download for a " +
                                "phone; use Wi-Fi and keep about ${SpeechStatusText.PHONON_DOWNLOAD_SIZE} free.",
                            style = MaterialTheme.typography.bodySmall
                        )
                        if (!phononSupported) {
                            Text(
                                "Phonon-2 cannot run on this device. Talkies uses Whisper tiny.",
                                style = MaterialTheme.typography.bodySmall
                            )
                        } else if (!phononReady) {
                            Button(
                                enabled = !anyDownloadBusy() && !recording && !transcribing,
                                onClick = { downloadPhonon() }
                            ) {
                                Text(
                                    if (phononBusy) "Downloading Phonon-2…"
                                    else "Download Phonon-2 (${SpeechStatusText.PHONON_DOWNLOAD_SIZE})"
                                )
                            }
                        } else {
                            Text("Phonon-2 ready", style = MaterialTheme.typography.labelLarge)
                            OutlinedButton(
                                enabled = !anyDownloadBusy() && !recording && !transcribing,
                                onClick = { deletePhonon() }
                            ) { Text("Delete Phonon-2 model and attribution") }
                        }
                        if (phononBusy) {
                            LinearProgressIndicator(
                                progress = { phononProgress },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }

                        Text("Whisper tiny (smaller, multilingual)", style = MaterialTheme.typography.titleSmall)
                        Text(
                            "Download size: ${SpeechStatusText.WHISPER_DOWNLOAD_SIZE}. Used when Phonon-2 is " +
                                "unavailable or when you choose Whisper.",
                            style = MaterialTheme.typography.bodySmall
                        )
                        if (!modelReady) {
                            Button(
                                enabled = !anyDownloadBusy() && !recording && !transcribing,
                                onClick = { downloadModel() }
                            ) {
                                Text(
                                    if (modelBusy) "Downloading Whisper…"
                                    else "Download Whisper tiny (${SpeechStatusText.WHISPER_DOWNLOAD_SIZE})"
                                )
                            }
                        } else {
                            Text("Whisper tiny ready", style = MaterialTheme.typography.labelLarge)
                        }
                        if (modelBusy) {
                            LinearProgressIndicator(
                                progress = { modelProgress },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        if (phononReady) {
                            Text(
                                "Phonon-2 by Fermion Research, derived from NVIDIA Parakeet TDT 0.6B v3 · CC-BY-4.0. " +
                                    "Its LICENSE and NOTICE are kept beside the model.",
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        Text("Optional local cleanup", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "S1-mini removes speech disfluencies and formats the transcript on this device. " +
                                "Its English model is downloaded only when you ask for it (about 462 MiB).",
                            style = MaterialTheme.typography.bodySmall
                        )
                        if (!cleanupModelReady) {
                            Button(
                                enabled = !anyDownloadBusy() && !recording && !transcribing,
                                onClick = { downloadCleanupModel() }
                            ) {
                                Text(if (cleanupBusy) "Downloading S1-mini…" else "Download S1-mini cleanup model")
                            }
                        } else {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Checkbox(
                                    checked = cleanupEnabled,
                                    enabled = !recording && !transcribing && !cleanupBusy,
                                    onCheckedChange = { enabled ->
                                        cleanupEnabled = enabled
                                        preferences.edit().putBoolean("s1-mini-enabled", enabled).apply()
                                    }
                                )
                                Text("Clean dictation locally with S1-mini")
                            }
                            OutlinedButton(
                                enabled = !anyDownloadBusy() && !recording && !transcribing,
                                onClick = { deleteCleanupModel() }
                            ) { Text("Delete S1-mini model and attribution") }
                        }
                        if (cleanupBusy) {
                            LinearProgressIndicator(
                                progress = { cleanupProgress },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        if (cleanupModelReady && cleanupEnabled) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                CleanupOptionSelector(
                                    "Tone", cleanupStyle.label,
                                    TranscriptStyle.entries.map { it.label },
                                    !recording && !transcribing
                                ) { selected ->
                                    cleanupStyle = TranscriptStyle.entries.first { it.label == selected }
                                    preferences.edit().putString("s1-mini-style", cleanupStyle.name).apply()
                                }
                                CleanupOptionSelector(
                                    "Format", cleanupStructure.wireValue,
                                    TranscriptStructure.entries.map { it.wireValue },
                                    !recording && !transcribing
                                ) { selected ->
                                    cleanupStructure = TranscriptStructure.entries.first { it.wireValue == selected }
                                    preferences.edit().putString("s1-mini-structure", cleanupStructure.name).apply()
                                }
                                CleanupOptionSelector(
                                    "Context", cleanupContext.wireValue,
                                    TranscriptContext.entries.map { it.wireValue },
                                    !recording && !transcribing
                                ) { selected ->
                                    cleanupContext = TranscriptContext.entries.first { it.wireValue == selected }
                                    preferences.edit().putString("s1-mini-context", cleanupContext.name).apply()
                                }
                            }
                            Text(
                                "S1-mini by Superwhisper · Apache 2.0. Its LICENSE and NOTICE are kept beside the model.",
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Button(
                                enabled = dictationEngines.isNotEmpty() && !recording && !transcribing && !anyDownloadBusy(),
                                onClick = {
                                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                                        startRecording()
                                    } else requestPermission.launch(Manifest.permission.RECORD_AUDIO)
                                }
                            ) { Text("Record") }
                            OutlinedButton(enabled = recording, onClick = { stopRecording() }) { Text("Stop") }
                            OutlinedButton(enabled = transcript.isNotBlank(), onClick = { copyTranscript(context) }) {
                                Text("Copy")
                            }
                        }

                        if (modelReady && !anyDownloadBusy() && !recording && !transcribing) {
                            OutlinedButton(onClick = { deleteModel() }) { Text("Delete Whisper tiny model") }
                        }

                        Text("Transcript history", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "Finished dictations are saved on this device so you can find, copy, or delete them " +
                                "later. Turning this off stops saving but keeps what is already saved.",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Checkbox(
                                checked = historyEnabled,
                                onCheckedChange = { enabled ->
                                    historyEnabled = enabled
                                    TranscriptHistory.setEnabled(preferences, enabled)
                                }
                            )
                            Text("Save transcript history")
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedButton(onClick = { showHistory = true }) { Text("View history") }
                            OutlinedButton(onClick = { confirmClearHistory = true }) { Text("Clear history") }
                        }
                        if (confirmClearHistory) {
                            AlertDialog(
                                onDismissRequest = { confirmClearHistory = false },
                                title = { Text("Clear transcript history?") },
                                text = { Text("This permanently deletes every saved transcript on this device.") },
                                confirmButton = {
                                    TextButton(onClick = {
                                        confirmClearHistory = false
                                        clearHistory(lifecycleScope, TranscriptHistory.store(context)) {
                                            status = HistoryText.cleared(it)
                                        }
                                    }) { Text("Clear all") }
                                },
                                dismissButton = {
                                    TextButton(onClick = { confirmClearHistory = false }) { Text("Cancel") }
                                }
                            )
                        }

                        TextField(
                            value = transcript,
                            onValueChange = { transcript = it },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 8,
                            label = { Text("Transcript") },
                            placeholder = { Text("Your recognized words will appear here.") }
                        )
                        Text(
                            "Speech recognition runs on this device. Internet access is used only when you choose to download a model; recording and transcription do not use a network service.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
        refreshModelStatus(updateStatus = true)
    }

    private fun anyDownloadBusy(): Boolean = modelBusy || phononBusy || cleanupBusy

    /** Re-checks installed models off the main thread. Only [updateStatus] replaces the status line. */
    private fun refreshModelStatus(updateStatus: Boolean = false) {
        val preference = enginePreference
        lifecycleScope.launch {
            val snapshot = withContext(Dispatchers.IO) {
                ModelSnapshot(
                    whisperReady = speechModels.whisperStore.isInstalled(),
                    phononReady = speechModels.phononStore.isInstalled(),
                    phononSupported = speechModels.phononRuntimeSupported,
                    cleanupReady = cleanupModelStore.isInstalled(),
                    engines = speechModels.chain.plan(preference),
                )
            }
            modelReady = snapshot.whisperReady
            phononReady = snapshot.phononReady
            phononSupported = snapshot.phononSupported
            cleanupModelReady = snapshot.cleanupReady
            dictationEngines = snapshot.engines
            if (updateStatus) status = SpeechStatusText.readiness(snapshot.engines, preference)
        }
    }

    private data class ModelSnapshot(
        val whisperReady: Boolean,
        val phononReady: Boolean,
        val phononSupported: Boolean,
        val cleanupReady: Boolean,
        val engines: List<SpeechEngine>,
    )

    /** Returns null when [requiredBytes] fit in app storage; otherwise a message to show. */
    private suspend fun storageProblem(name: String, requiredBytes: Long): String? {
        val available = withContext(Dispatchers.IO) { filesDir.usableSpace }
        return if (available < requiredBytes) SpeechStatusText.notEnoughStorage(name, requiredBytes, available) else null
    }

    private fun downloadPhonon() {
        if (anyDownloadBusy() || recording || transcribing) return
        phononBusy = true
        phononProgress = 0f
        status = "Checking storage for Phonon-2…"
        lifecycleScope.launch {
            try {
                storageProblem("Phonon-2", Phonon2ModelStore.DOWNLOAD_SIZE_BYTES)?.let {
                    status = it
                    return@launch
                }
                status = "Downloading and verifying Phonon-2 (${SpeechStatusText.PHONON_DOWNLOAD_SIZE})…"
                speechModels.phononStore.download { progress ->
                    runOnUiThread {
                        phononProgress = progress.downloadedBytes.toFloat() / progress.totalBytes.toFloat()
                        status = SpeechStatusText.downloadProgress("Phonon-2", progress.downloadedBytes, progress.totalBytes)
                    }
                }
                status = "Phonon-2 verified. Dictation runs offline."
            } catch (error: Exception) {
                status = error.message ?: "Phonon-2 could not be downloaded or verified."
            } finally {
                phononBusy = false
                refreshModelStatus()
            }
        }
    }

    private fun deletePhonon() {
        if (recording || transcribing || anyDownloadBusy()) return
        phononBusy = true
        lifecycleScope.launch {
            val deleted = withContext(Dispatchers.IO) {
                runCatching { speechModels.phononStore.delete() }.getOrDefault(false)
            }
            phononBusy = false
            refreshModelStatus()
            status = if (deleted) "Phonon-2 model and attribution files deleted." else
                "Could not fully delete Phonon-2. Check local model storage."
        }
    }

    private fun downloadModel() {
        if (anyDownloadBusy() || recording || transcribing) return
        modelBusy = true
        modelProgress = 0f
        status = "Downloading and verifying Whisper tiny (${SpeechStatusText.WHISPER_DOWNLOAD_SIZE})…"
        lifecycleScope.launch {
            try {
                storageProblem("Whisper tiny", WhisperTinyModelStore.MODEL_SIZE_BYTES)?.let {
                    status = it
                    return@launch
                }
                speechModels.whisperStore.download { progress ->
                    runOnUiThread {
                        modelProgress = progress.downloadedBytes.toFloat() / progress.totalBytes.toFloat()
                        status = SpeechStatusText.downloadProgress("Whisper tiny", progress.downloadedBytes, progress.totalBytes)
                    }
                }
                modelReady = true
                status = "Whisper model verified. Dictation is ready offline."
            } catch (error: Exception) {
                status = error.message ?: "The Whisper model could not be downloaded or verified."
            } finally {
                modelBusy = false
                refreshModelStatus()
            }
        }
    }

    private fun deleteModel() {
        if (recording || transcribing || anyDownloadBusy()) return
        lifecycleScope.launch {
            modelReady = false
            val (deleted, stillInstalled) = withContext(Dispatchers.IO) {
                val deleteSucceeded = runCatching { speechModels.whisperStore.delete() }.getOrDefault(false)
                val modelIsReady = runCatching { speechModels.whisperStore.isInstalled() }.getOrDefault(false)
                deleteSucceeded to modelIsReady
            }
            modelReady = stillInstalled
            refreshModelStatus()
            status = when {
                deleted && !stillInstalled -> "Whisper tiny model deleted."
                stillInstalled -> "Could not delete Whisper tiny. It remains ready for dictation."
                else -> "Whisper tiny is unavailable. Download it again before using it."
            }
        }
    }

    private fun downloadCleanupModel() {
        if (anyDownloadBusy() || recording || transcribing) return
        cleanupBusy = true
        cleanupProgress = 0f
        status = "Downloading the optional S1-mini cleanup model…"
        lifecycleScope.launch {
            try {
                cleanupModelStore.download { progress ->
                    runOnUiThread {
                        cleanupProgress = progress.downloadedBytes.toFloat() / progress.totalBytes.toFloat()
                        val downloadedMiB = progress.downloadedBytes / (1024 * 1024)
                        status = "Downloading S1-mini… $downloadedMiB / 462 MiB"
                    }
                }
                cleanupModelReady = true
                cleanupEnabled = true
                getSharedPreferences("talkies-settings", MODE_PRIVATE).edit()
                    .putBoolean("s1-mini-enabled", true)
                    .apply()
                status = "S1-mini is verified. Local transcript cleanup is on."
            } catch (error: Exception) {
                status = error.message ?: "S1-mini could not be downloaded or verified."
            } finally {
                cleanupBusy = false
            }
        }
    }

    private fun deleteCleanupModel() {
        if (anyDownloadBusy() || recording || transcribing) return
        cleanupBusy = true
        lifecycleScope.launch {
            val deleted = withContext(Dispatchers.IO) {
                runCatching { cleanupModelStore.delete() }.getOrDefault(false)
            }
            cleanupModelReady = withContext(Dispatchers.IO) { cleanupModelStore.isInstalled() }
            if (!cleanupModelReady) {
                cleanupEnabled = false
                getSharedPreferences("talkies-settings", MODE_PRIVATE).edit()
                    .putBoolean("s1-mini-enabled", false)
                    .apply()
            }
            status = if (deleted && !cleanupModelReady) {
                "S1-mini model and attribution files deleted."
            } else {
                "Could not fully delete S1-mini. Check local model storage before cleanup."
            }
            cleanupBusy = false
        }
    }

    private fun startRecording() {
        if (dictationEngines.isEmpty() || anyDownloadBusy() || recording || transcribing) return
        try {
            audioCapture.start {
                runOnUiThread { stopRecording(maximumDurationReached = true) }
            }
            recording = true
            status = "Recording. Audio remains in memory on this device."
        } catch (error: Exception) {
            audioCapture.cancel()
            status = error.message ?: "Could not start microphone capture."
        }
    }

    private fun stopRecording(maximumDurationReached: Boolean = false) {
        if (!recording) return
        recording = false
        transcribing = true
        status = if (maximumDurationReached) {
            "${OfflineAudioCapture.MAX_RECORDING_SECONDS / 60}-minute limit reached. Transcribing locally…"
        } else {
            "Transcribing locally…"
        }
        val preference = enginePreference
        lifecycleScope.launch {
            var samples: FloatArray? = null
            try {
                samples = withContext(Dispatchers.IO) { audioCapture.stop() }
                val outcome = withContext(Dispatchers.Default) {
                    speechModels.chain.transcribe(requireNotNull(samples), preference)
                }
                val recognized = outcome.transcript.trim()
                if (recognized.isBlank()) {
                    remoteDictationSink = null
                    remoteDictationInProgress = false
                    status = "No speech was recognized. Try again when ready."
                } else {
                    val remoteSink = remoteDictationSink
                    if (remoteDictationInProgress) {
                        remoteDictationSink = null
                        remoteDictationInProgress = false
                        if (remoteSink != null) {
                            remoteSink(TerminalInputPolicy.stage(recognized))
                            status = "Local dictation delivered without submission. Review it before continuing."
                        }
                    } else {
                        var cleanupFailed = false
                        val cleaned = if (cleanupEnabled && cleanupModelReady) {
                            status = "Cleaning transcript locally with S1-mini…"
                            try {
                                cleanupCleaner.clean(
                                    recognized,
                                    TranscriptCleanupOptions(cleanupStyle, cleanupStructure, cleanupContext)
                                )
                            } catch (_: Exception) {
                                cleanupFailed = true
                                recognized
                            }
                        } else {
                            recognized
                        }
                        transcript = appendTranscript(transcript, cleaned)
                        if (cleaned.isNotBlank()) {
                            val entry = NewTranscript.of(
                                text = cleaned,
                                rawText = recognized,
                                engine = outcome.engine,
                                durationMillis = pcmDurationMillis(requireNotNull(samples).size),
                            )
                            val appContext = applicationContext
                            val preferences = getSharedPreferences(SpeechSettings.PREFERENCES, MODE_PRIVATE)
                            lifecycleScope.launch(Dispatchers.IO) {
                                TranscriptHistory.saveIfEnabled(appContext, preferences, entry)
                            }
                        }
                        status = when {
                            cleanupFailed -> "Cleanup failed; kept the raw local ${outcome.engine.label} transcript."
                            cleanupEnabled && cleanupModelReady ->
                                "${outcome.engine.label} transcription and S1-mini cleanup complete offline."
                            else -> SpeechStatusText.completed(outcome, preference)
                        }
                    }
                }
            } catch (error: Exception) {
                remoteDictationSink = null
                remoteDictationInProgress = false
                status = error.message ?: "Local transcription failed. Try again."
            } finally {
                samples?.fill(0f)
                transcribing = false
                refreshModelStatus()
            }
        }
    }

    private fun copyTranscript(context: Context) {
        val clipboard = context.getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Talkies transcript", transcript))
        status = "Transcript copied."
    }

    override fun onDestroy() {
        if (recording) audioCapture.cancel()
        super.onDestroy()
    }

    override fun onStop() {
        if (recording) {
            audioCapture.cancel()
            recording = false
            status = "Recording stopped because Talkies left the foreground."
        }
        super.onStop()
    }
}
