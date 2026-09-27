package com.talkies.android

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
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

class MainActivity : ComponentActivity() {
    private var recognizer: SpeechRecognizer? = null
    private var transcript by mutableStateOf("")
    private var status by mutableStateOf("Ready. Speech stays on this device when Android offers offline recognition.")
    private var listening by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                val context = LocalContext.current
                val requestPermission = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission()
                ) { granted ->
                    if (granted) startOnDeviceRecognition() else status = "Microphone permission is needed to dictate."
                }
                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text("Talkies", style = MaterialTheme.typography.headlineLarge)
                        Text("Private, on-device dictation", style = MaterialTheme.typography.titleMedium)
                        Text(status, style = MaterialTheme.typography.bodyMedium)
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Button(
                                enabled = !listening,
                                onClick = {
                                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                                        startOnDeviceRecognition()
                                    } else requestPermission.launch(Manifest.permission.RECORD_AUDIO)
                                }
                            ) { Text("Record") }
                            OutlinedButton(enabled = listening, onClick = { stopRecognition() }) { Text("Stop") }
                            OutlinedButton(enabled = transcript.isNotBlank(), onClick = { copyTranscript(context) }) { Text("Copy") }
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
                            "Uses Android's on-device speech service only. Talkies does not include a speech model yet. If offline recognition is unavailable, recording is disabled instead of using a network service.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }

    private fun startOnDeviceRecognition() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            status = "On-device speech recognition is unavailable on this device. No network recognizer will be used."
            listening = false
            return
        }
        try {
            recognizer?.destroy()
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this).also { service ->
                service.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) { status = "Listening on device…" }
                    override fun onBeginningOfSpeech() { status = "Hearing speech…" }
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() { status = "Finishing transcription…" }
                    override fun onError(error: Int) {
                        listening = false
                        status = when (error) {
                            SpeechRecognizer.ERROR_NO_MATCH -> "No speech was recognized. Try again when ready."
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is needed to dictate."
                            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "Offline recognition for this language is unavailable on this device."
                            else -> "On-device recognition stopped (code $error). Try again."
                        }
                    }
                    override fun onResults(results: Bundle?) {
                        listening = false
                        val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                        if (text.isNotBlank()) transcript = appendTranscript(transcript, text)
                        status = if (text.isBlank()) "No speech was recognized. Try again when ready." else "Transcription complete."
                    }
                    override fun onPartialResults(partialResults: Bundle?) {
                        val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                        if (!partial.isNullOrBlank()) status = "Listening on device… $partial"
                    }
                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                })
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                service.startListening(intent)
                listening = true
            }
        } catch (_: RuntimeException) {
            listening = false
            status = "Could not start Android's on-device speech recognizer. No network fallback was attempted."
        }
    }

    private fun stopRecognition() {
        recognizer?.stopListening()
        listening = false
        status = "Finishing transcription…"
    }

    private fun copyTranscript(context: Context) {
        val clipboard = context.getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Talkies transcript", transcript))
        status = "Transcript copied."
    }

    override fun onDestroy() {
        recognizer?.destroy()
        recognizer = null
        super.onDestroy()
    }
}
