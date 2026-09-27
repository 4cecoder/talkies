package com.talkies.android

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
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
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : ComponentActivity() {
    private lateinit var modelStore: WhisperTinyModelStore
    private val audioCapture = OfflineAudioCapture()
    private var transcript by mutableStateOf("")
    private var status by mutableStateOf("Download the local Whisper model to get started.")
    private var modelReady by mutableStateOf(false)
    private var modelBusy by mutableStateOf(false)
    private var modelProgress by mutableStateOf(0f)
    private var recording by mutableStateOf(false)
    private var transcribing by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        modelStore = WhisperTinyModelStore(File(filesDir, "models"))
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

                        if (!modelReady) {
                            Button(enabled = !modelBusy, onClick = { downloadModel() }) {
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

                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Button(
                                enabled = modelReady && !recording && !transcribing,
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

                        if (modelReady && !modelBusy && !recording && !transcribing) {
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
            modelReady = withContext(Dispatchers.IO) { modelStore.isInstalled() }
            status = if (modelReady) "Ready for offline dictation." else "Download the local Whisper model to get started."
        }
    }

    private fun downloadModel() {
        if (modelBusy || recording || transcribing) return
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
        if (recording || transcribing || modelBusy) return
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

    private fun startRecording() {
        if (!modelReady || recording || transcribing) return
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
                val modelFile = withContext(Dispatchers.IO) {
                    check(modelStore.isInstalled()) { "The local Whisper model is missing or invalid. Download it again." }
                    modelStore.modelFile
                }
                val recognized = withContext(Dispatchers.Default) {
                    LocalWhisper.transcribe(modelFile.absolutePath, requireNotNull(samples))
                }.trim()
                if (recognized.isBlank()) {
                    status = "No speech was recognized. Try again when ready."
                } else {
                    transcript = appendTranscript(transcript, recognized)
                    status = "Transcription complete. Whisper ran locally."
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
