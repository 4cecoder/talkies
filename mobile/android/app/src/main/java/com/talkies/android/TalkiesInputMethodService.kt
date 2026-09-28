package com.talkies.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
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
    private lateinit var modelStore: WhisperTinyModelStore
    private lateinit var cleanupModelStore: S1MiniModelStore
    private lateinit var cleanupCleaner: S1MiniCleaner
    private var recording = false
    private var processing = false
    private var inputSession = 0
    private var statusView: TextView? = null
    private var recordButton: Button? = null

    override fun onCreate() {
        super.onCreate()
        modelStore = WhisperTinyModelStore(File(filesDir, "models"))
        cleanupModelStore = S1MiniModelStore(
            File(File(filesDir, "models"), "S1-mini-${S1MiniModelStore.MODEL_REVISION}")
        )
        cleanupCleaner = S1MiniCleaner(cleanupModelStore)
    }

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(16, 12, 16, 12)
        }
        statusView = TextView(this).apply {
            text = "Talkies offline voice typing"
            gravity = android.view.Gravity.CENTER_VERTICAL
        }
        recordButton = Button(this).apply {
            text = "Record"
            setOnClickListener { onRecordButtonPressed() }
        }
        root.addView(statusView, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        root.addView(recordButton)
        updateControls("Ready")
        return root
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        inputSession += 1
        if (!recording && !processing) updateControls("Talkies offline voice typing")
    }

    override fun onFinishInput() {
        inputSession += 1
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
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            updateControls("Grant microphone permission in Talkies first")
            return
        }
        processing = true
        updateControls("Checking local model…")
        serviceScope.launch {
            try {
                val ready = withContext(Dispatchers.IO) { modelStore.isInstalled() }
                if (!ready) {
                    updateControls("Download Whisper in Talkies first")
                    return@launch
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
                recordButton?.isEnabled = true
            }
        }
    }

    private fun finishRecording(maximumDurationReached: Boolean = false) {
        if (!recording || processing) return
        recording = false
        processing = true
        val targetSession = inputSession
        updateControls(if (maximumDurationReached) "Time limit · transcribing…" else "Transcribing offline…")
        serviceScope.launch {
            var samples: FloatArray? = null
            try {
                samples = withContext(Dispatchers.IO) { audioCapture.stop() }
                val modelPath = withContext(Dispatchers.IO) {
                    check(modelStore.isInstalled()) { "Whisper model is missing. Open Talkies to download it." }
                    modelStore.modelFile.absolutePath
                }
                var result = withContext(Dispatchers.Default) {
                    LocalWhisper.transcribe(modelPath, requireNotNull(samples))
                }.trim()
                check(result.isNotBlank()) { "No speech recognized. Try again." }

                val settings = getSharedPreferences("talkies-settings", Context.MODE_PRIVATE)
                val cleanupReady = settings.getBoolean("s1-mini-enabled", false) &&
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
                check(targetSession == inputSession) { "The text field changed before dictation finished." }
                val connection = currentInputConnection
                    ?: error("The active text field closed before insertion completed.")
                val selectedText = connection.getSelectedText(0)?.toString().orEmpty()
                val beforeCursor = connection.getTextBeforeCursor(1, 0)?.toString().orEmpty()
                val insertion = if (selectedText.isNotEmpty()) result else appendDictationSpacing(beforeCursor, result)
                if (!connection.commitText(insertion, 1)) {
                    error("The app did not accept the dictated text.")
                }
                updateControls("Inserted ✓")
            } catch (error: Exception) {
                updateControls(error.message ?: "Dictation failed. Try again.")
            } finally {
                samples?.fill(0f)
                processing = false
                recordButton?.text = "Record"
                recordButton?.isEnabled = true
            }
        }
    }

    private fun updateControls(message: String) {
        statusView?.text = message
        recordButton?.apply {
            isEnabled = !processing
            text = if (recording) "Stop" else "Record"
        }
    }

    override fun onDestroy() {
        if (recording) audioCapture.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }
}
