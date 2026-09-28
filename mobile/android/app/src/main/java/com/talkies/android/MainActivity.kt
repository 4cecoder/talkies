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
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
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
    private lateinit var modelStore: WhisperTinyModelStore
    private lateinit var speechRecognizer: SpeechRecognizer
    private lateinit var cleanupModelStore: S1MiniModelStore
    private lateinit var cleanupCleaner: TranscriptCleaner
    private val audioCapture = OfflineAudioCapture()
    private var transcript by mutableStateOf("")
    private var status by mutableStateOf("Download the local Whisper model to get started.")
    private var modelReady by mutableStateOf(false)
    private var modelBusy by mutableStateOf(false)
    private var modelProgress by mutableStateOf(0f)
    private var cleanupModelReady by mutableStateOf(false)
    private var cleanupBusy by mutableStateOf(false)
    private var cleanupProgress by mutableStateOf(0f)
    private var cleanupEnabled by mutableStateOf(false)
    private var cleanupStyle by mutableStateOf(TranscriptStyle.SEMI_FORMAL)
    private var cleanupStructure by mutableStateOf(TranscriptStructure.PROSE)
    private var cleanupContext by mutableStateOf(TranscriptContext.GENERAL)
    private var recording by mutableStateOf(false)
    private var transcribing by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        modelStore = WhisperTinyModelStore(File(filesDir, "models"))
        speechRecognizer = WhisperTinyRecognizer(modelStore)
        cleanupModelStore = S1MiniModelStore(
            File(File(filesDir, "models"), "S1-mini-${S1MiniModelStore.MODEL_REVISION}")
        )
        cleanupCleaner = S1MiniCleaner(cleanupModelStore)
        val preferences = getSharedPreferences("talkies-settings", MODE_PRIVATE)
        cleanupEnabled = preferences.getBoolean("s1-mini-enabled", false)
        cleanupStyle = enumValueOrDefault(preferences.getString("s1-mini-style", null), TranscriptStyle.SEMI_FORMAL)
        cleanupStructure = enumValueOrDefault(preferences.getString("s1-mini-structure", null), TranscriptStructure.PROSE)
        cleanupContext = enumValueOrDefault(preferences.getString("s1-mini-context", null), TranscriptContext.GENERAL)
        setContent {
            MaterialTheme {
                val context = LocalContext.current
                val requestPermission = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission()
                ) { granted ->
                    if (granted) startRecording() else status = "Microphone permission is needed to dictate."
                }
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text("Talkies", style = MaterialTheme.typography.headlineLarge)
                        Text("Private, on-device dictation", style = MaterialTheme.typography.titleMedium)
                        Text(status, style = MaterialTheme.typography.bodyMedium)

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

                        if (!modelReady) {
                            Button(enabled = !modelBusy && !cleanupBusy, onClick = { downloadModel() }) {
                                Text(if (modelBusy) "Downloading Whisper…" else "Download Whisper tiny (77 MB)")
                            }
                        } else {
                            Text("Local Whisper model ready", style = MaterialTheme.typography.labelLarge)
                        }
                        if (modelBusy) {
                            LinearProgressIndicator(
                                progress = { modelProgress },
                                modifier = Modifier.fillMaxWidth()
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
                                enabled = !modelBusy && !cleanupBusy && !recording && !transcribing,
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
                                enabled = !modelBusy && !recording && !transcribing && !cleanupBusy,
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
                                enabled = modelReady && !recording && !transcribing && !cleanupBusy,
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

                        if (modelReady && !modelBusy && !cleanupBusy && !recording && !transcribing) {
                            OutlinedButton(onClick = { deleteModel() }) { Text("Delete local model") }
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
                            "Whisper runs on this device. Internet access is used only when you choose to download the model; recording and transcription do not use a network service.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
        refreshModelStatus()
    }

    private fun refreshModelStatus() {
        lifecycleScope.launch {
            val installedModels = withContext(Dispatchers.IO) {
                modelStore.isInstalled() to cleanupModelStore.isInstalled()
            }
            modelReady = installedModels.first
            cleanupModelReady = installedModels.second
            status = if (modelReady) "Ready for offline dictation." else "Download the local Whisper model to get started."
        }
    }

    private fun downloadModel() {
        if (modelBusy || cleanupBusy || recording || transcribing) return
        modelBusy = true
        modelProgress = 0f
        status = "Downloading and verifying the local speech model…"
        lifecycleScope.launch {
            try {
                modelStore.download { progress ->
                    runOnUiThread {
                        modelProgress = progress.downloadedBytes.toFloat() / progress.totalBytes.toFloat()
                        val downloadedMb = progress.downloadedBytes / (1024 * 1024)
                        status = "Downloading Whisper tiny… $downloadedMb / 74 MB"
                    }
                }
                modelReady = true
                status = "Whisper model verified. Dictation is ready offline."
            } catch (error: Exception) {
                status = error.message ?: "The Whisper model could not be downloaded or verified."
            } finally {
                modelBusy = false
            }
        }
    }

    private fun deleteModel() {
        if (recording || transcribing || modelBusy || cleanupBusy) return
        lifecycleScope.launch {
            modelReady = false
            val (deleted, stillInstalled) = withContext(Dispatchers.IO) {
                val deleteSucceeded = runCatching { modelStore.delete() }.getOrDefault(false)
                val modelIsReady = runCatching { modelStore.isInstalled() }.getOrDefault(false)
                deleteSucceeded to modelIsReady
            }
            modelReady = stillInstalled
            status = when {
                deleted && !stillInstalled -> "Local speech model deleted."
                stillInstalled -> "Could not delete the local speech model. It remains ready for dictation."
                else -> "The local speech model is unavailable. Download it again before dictating."
            }
        }
    }

    private fun downloadCleanupModel() {
        if (modelBusy || cleanupBusy || recording || transcribing) return
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
        if (modelBusy || recording || transcribing || cleanupBusy) return
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
        if (!modelReady || modelBusy || cleanupBusy || recording || transcribing) return
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
        lifecycleScope.launch {
            var samples: FloatArray? = null
            try {
                samples = withContext(Dispatchers.IO) { audioCapture.stop() }
                val recognized = withContext(Dispatchers.Default) {
                    speechRecognizer.transcribe(requireNotNull(samples))
                }.trim()
                if (recognized.isBlank()) {
                    status = "No speech was recognized. Try again when ready."
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
                    status = when {
                        cleanupFailed -> "Cleanup failed; kept the raw local Whisper transcript."
                        cleanupEnabled && cleanupModelReady -> "Transcription and S1-mini cleanup complete offline."
                        else -> "Transcription complete. Whisper ran locally."
                    }
                }
            } catch (error: Exception) {
                status = error.message ?: "Local transcription failed. Try again."
            } finally {
                samples?.fill(0f)
                transcribing = false
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
