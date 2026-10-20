package com.talkies.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** Offline voice input method that commits the cleaned transcript into the focused editor. */
class TalkiesInputMethodService : InputMethodService() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val audioCapture = OfflineAudioCapture()
    private lateinit var speechModels: LocalSpeechModels
    private lateinit var cleanupModelStore: S1MiniModelStore
    private lateinit var cleanupCleaner: TranscriptCleaner
    private var recording by mutableStateOf(false)
    private var processing by mutableStateOf(false)
    private var inputSession = 0
    private var inputViewGeneration = 0
    private var inputViewActive = false
    private var historyAllowedForField = false
    private var destination = DictationDestination.GENERAL
    private var keyboardStatus by mutableStateOf("Ready for private, on-device dictation")

    override fun onCreate() {
        super.onCreate()
        speechModels = LocalSpeechModels(filesDir)
        cleanupModelStore = S1MiniModelStore(
            File(File(filesDir, "models"), "S1-mini-${S1MiniModelStore.MODEL_REVISION}")
        )
        cleanupCleaner = S1MiniCleaner(cleanupModelStore)
    }

    override fun onCreateInputView(): View {
        val root = ComposeView(this).apply {
            setContent {
                TalkiesTheme {
                    Surface(color = MaterialTheme.colorScheme.surface) {
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text("TALKIES · PRIVATE VOICE", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                Text(
                                    keyboardStatus,
                                    style = MaterialTheme.typography.bodySmall,
                                    maxLines = 2,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Button(
                                enabled = !processing,
                                onClick = { onRecordButtonPressed() },
                            ) {
                                Text(if (recording) "■  Stop" else "●  Speak")
                            }
                            IconButton(
                                onClick = { requestHideSelf(0) },
                                modifier = Modifier.size(44.dp).semantics { contentDescription = "Hide Talkies keyboard" },
                            ) {
                                TalkiesGlyph(TalkiesGlyphKind.HIDE, MaterialTheme.colorScheme.secondary, Modifier.size(24.dp))
                            }
                        }
                    }
                }
            }
        }
        updateControls("Ready")
        return root
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        inputSession += 1
        destination = DictationDestinationResolver.fromPackageName(attribute?.packageName)
        if (!recording && !processing) updateControls(readyStatus())
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        inputViewGeneration += 1
        inputViewActive = true
        destination = DictationDestinationResolver.fromPackageName(info?.packageName)
        historyAllowedForField = info != null && KeyboardHistoryPolicy.allowsHistory(info.inputType, info.imeOptions)
        if (!recording && !processing) updateControls(readyStatus())
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        inputViewGeneration += 1
        inputViewActive = false
        if (recording) {
            audioCapture.cancel()
            recording = false
            updateControls("Recording cancelled")
        }
        super.onFinishInputView(finishingInput)
    }

    override fun onFinishInput() {
        inputSession += 1
        inputViewActive = false
        if (recording) {
            audioCapture.cancel()
            recording = false
        }
        super.onFinishInput()
    }

    private fun onRecordButtonPressed() {
        if (recording) {
            finishRecording()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        if (processing || recording) return
        val targetSession = inputSession
        val targetViewGeneration = inputViewGeneration
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            updateControls("Grant microphone permission in Talkies first")
            return
        }
        processing = true
        updateControls("Checking local model…")
        serviceScope.launch {
            try {
                val preference = SpeechSettings.enginePreference(
                    getSharedPreferences(SpeechSettings.PREFERENCES, Context.MODE_PRIVATE)
                )
                val ready = withContext(Dispatchers.IO) { speechModels.chain.plan(preference).isNotEmpty() }
                if (!ready) {
                    updateControls(SpeechStatusText.missingModel(preference))
                    return@launch
                }
                check(targetSession == inputSession && targetViewGeneration == inputViewGeneration && inputViewActive) {
                    "The text field changed before recording could start."
                }
                processing = false
                audioCapture.start {
                    serviceScope.launch { finishRecording(maximumDurationReached = true) }
                }
                recording = true
                updateControls("Recording offline…")
            } catch (error: Exception) {
                audioCapture.cancel()
                updateControls(error.message ?: "Could not start microphone")
            } finally {
                processing = false
            }
        }
    }

    private fun finishRecording(maximumDurationReached: Boolean = false) {
        if (!recording || processing) return
        recording = false
        processing = true
        val targetSession = inputSession
        val targetViewGeneration = inputViewGeneration
        val targetDestination = destination
        updateControls(if (maximumDurationReached) "Time limit · transcribing…" else "Transcribing offline…")
        serviceScope.launch {
            var samples: FloatArray? = null
            try {
                samples = withContext(Dispatchers.IO) { audioCapture.stop() }
                val settings = getSharedPreferences(SpeechSettings.PREFERENCES, Context.MODE_PRIVATE)
                val preference = SpeechSettings.enginePreference(settings)
                val outcome = withContext(Dispatchers.Default) {
                    speechModels.chain.transcribe(requireNotNull(samples), preference)
                }
                val recognized = outcome.transcript.trim()
                check(recognized.isNotBlank()) { "No speech recognized. Try again." }
                var result = recognized
                val durationMillis = pcmDurationMillis(requireNotNull(samples).size)
                // Agent prompts and terminal commands can contain private project details. Keep
                // terminal dictation out of transcript history unless it is explicitly copied out.
                val saveToHistory = targetDestination.allowsHistory(historyAllowedForField)

                // LLM cleanup adds latency and can rewrite code identifiers or agent instructions.
                val cleanupReady = targetDestination.allowsCleanup(settings.getBoolean("s1-mini-enabled", false)) &&
                    withContext(Dispatchers.IO) { cleanupModelStore.isInstalled() }
                if (cleanupReady) {
                    updateControls("Cleaning locally…")
                    val options = TranscriptCleanupOptions(
                        enumValueOrDefault(settings.getString("s1-mini-style", null), TranscriptStyle.SEMI_FORMAL),
                        enumValueOrDefault(settings.getString("s1-mini-structure", null), TranscriptStructure.PROSE),
                        enumValueOrDefault(settings.getString("s1-mini-context", null), TranscriptContext.GENERAL)
                    )
                    result = runCatching { cleanupCleaner.clean(result, options) }.getOrDefault(result)
                }
                check(
                    targetSession == inputSession && targetViewGeneration == inputViewGeneration && inputViewActive
                ) { "The text field closed before dictation finished." }
                val connection = currentInputConnection
                    ?: error("The active text field closed before insertion completed.")
                val selectedText = connection.getSelectedText(0)?.toString().orEmpty()
                val beforeCursor = connection.getTextBeforeCursor(1, 0)?.toString().orEmpty()
                val afterCursor = connection.getTextAfterCursor(1, 0)?.toString().orEmpty()
                val insertion = if (selectedText.isNotEmpty()) result else {
                    appendDictationSpacing(beforeCursor, result, afterCursor)
                }
                if (!connection.commitText(insertion, 1)) {
                    error("The app did not accept the dictated text.")
                }
                val insertionStatus = SpeechStatusText.inserted(outcome)
                updateControls(
                    if (targetDestination == DictationDestination.TERMINAL) {
                        "$insertionStatus Terminal text inserted for review; Talkies did not send or run it."
                    } else {
                        insertionStatus
                    }
                )
                if (saveToHistory && result.isNotBlank()) {
                    val entry = NewTranscript.of(result, recognized, outcome.engine, durationMillis)
                    val appContext = applicationContext
                    withContext(Dispatchers.IO) { TranscriptHistory.saveIfEnabled(appContext, settings, entry) }
                }
            } catch (error: Exception) {
                updateControls(error.message ?: "Dictation failed. Try again.")
            } finally {
                samples?.fill(0f)
                processing = false
            }
        }
    }

    private fun updateControls(message: String) {
        keyboardStatus = message
    }

    private fun readyStatus(): String = when (destination) {
        DictationDestination.GENERAL -> "Talkies offline voice typing"
        DictationDestination.TERMINAL -> "Terminal detected · local dictation · review before sending"
    }

    override fun onDestroy() {
        if (recording) audioCapture.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }
}
