package com.talkies.android

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import org.connectbot.terminal.Terminal
import org.connectbot.terminal.TerminalEmulatorFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import java.util.concurrent.CompletableFuture

private val terminalBackground = Color(0xFF080D19)
private val terminalForeground = Color(0xFFD9E7FF)
private val terminalAccent = Color(0xFF6FFFE9)

@Composable
internal fun SshCompanionScreen(context: Context, onBack: () -> Unit, onDictate: ((String) -> Unit) -> Unit) {
    val appContext = context.applicationContext
    val store = remember(appContext) { AndroidSshHostProfileStore(appContext) }
    val scope = rememberCoroutineScope()
    val mainHandler = remember { Handler(Looper.getMainLooper()) }
    var profiles by remember { mutableStateOf(store.list()) }
    var editing by remember { mutableStateOf(false) }
    var editId by remember { mutableStateOf<String?>(null) }
    var name by remember { mutableStateOf("") }
    var host by remember { mutableStateOf("") }
    var port by remember { mutableStateOf("22") }
    var username by remember { mutableStateOf("") }
    var formError by remember { mutableStateOf<String?>(null) }
    var pendingProfile by remember { mutableStateOf<SshHostProfile?>(null) }
    var password by remember { mutableStateOf("") }
    var connecting by remember { mutableStateOf(false) }
    var connectionError by remember { mutableStateOf<String?>(null) }
    var hostTrust by remember { mutableStateOf<HostTrustPrompt?>(null) }
    var activeProfile by remember { mutableStateOf<SshHostProfile?>(null) }
    var terminal by remember { mutableStateOf<SshTerminalSession?>(null) }
    var connected by remember { mutableStateOf(false) }
    var dictateAfterPermission by remember { mutableStateOf(false) }
    val terminalEmulator = remember {
        TerminalEmulatorFactory.create(
            looper = Looper.getMainLooper(),
            initialRows = 32,
            initialCols = 100,
            defaultForeground = terminalForeground,
            defaultBackground = terminalBackground,
            onKeyboardInput = { bytes ->
                terminal?.let { session ->
                    scope.launch(Dispatchers.IO) {
                        runCatching { session.send(bytes) }
                            .onFailure { error -> mainHandler.post { connectionError = error.message } }
                    }
                }
            },
            onResize = { dimensions ->
                terminal?.let { session ->
                    scope.launch(Dispatchers.IO) { runCatching { session.resize(dimensions.rows, dimensions.columns) } }
                }
            },
        )
    }
    val terminalForCleanup by rememberUpdatedState(terminal)
    val hostTrustForCleanup by rememberUpdatedState(hostTrust)
    DisposableEffect(terminalEmulator) {
        onDispose {
            hostTrustForCleanup?.answer?.complete(false)
            terminalForCleanup?.close()
        }
    }
    val requestMicrophone = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && dictateAfterPermission) {
            onDictate { text ->
                val safeText = TerminalInputPolicy.stage(text)
                if (safeText.isNotEmpty()) insertWithoutSubmit(terminalEmulator, safeText)
            }
        }
        dictateAfterPermission = false
    }

    fun connect(profile: SshHostProfile, secret: CharArray) {
        if (connecting) return
        connecting = true
        connectionError = null
        activeProfile = profile
        terminal?.close()
        terminal = null
        connected = false
        scope.launch {
            try {
                val next = withContext(Dispatchers.IO) {
                    SshTerminalSession.connect(
                        appContext,
                        profile,
                        secret,
                    ) { message, answer ->
                        mainHandler.post { hostTrust = HostTrustPrompt(message, answer) }
                    }
                }
                terminal = next
                connected = true
                next.startReading(
                    onBytes = { bytes -> terminalEmulator.writeInput(bytes) },
                    onClosed = { error ->
                        mainHandler.post {
                            connected = false
                            if (error != null) connectionError = "SSH connection interrupted. Reconnect to continue."
                        }
                    },
                )
                pendingProfile = null
                password = ""
            } catch (error: Exception) {
                connectionError = error.message?.take(400) ?: "SSH connection failed. Check the host and network."
                connected = false
            } finally {
                connecting = false
            }
        }
    }

    fun disconnect() {
        terminal?.close()
        terminal = null
        connected = false
        activeProfile = null
    }

    fun send(data: String) {
        val active = terminal ?: return
        scope.launch(Dispatchers.IO) {
            runCatching { active.send(data) }
                .onFailure { error -> mainHandler.post { connectionError = error.message } }
        }
    }

    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = terminalAccent,
            secondary = Color(0xFFB69CFF),
            background = Color(0xFF070B14),
            surface = Color(0xFF111827),
            onPrimary = Color(0xFF071018),
            onBackground = terminalForeground,
            onSurface = terminalForeground,
            error = Color(0xFFFF718B),
        ),
    ) {
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text("FIELD LINK", style = MaterialTheme.typography.labelLarge, color = terminalAccent)
                    Text("Remote companion", style = MaterialTheme.typography.headlineSmall)
                }
                TextButton(onClick = { disconnect(); onBack() }) { Text("Back") }
            }

            if (activeProfile == null) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("SSH HOSTS", style = MaterialTheme.typography.titleMedium)
                    Button(onClick = {
                        editId = null
                        name = ""
                        host = ""
                        port = "22"
                        username = ""
                        formError = null
                        editing = true
                    }) { Text("Add host") }
                }
                Text(
                    "Save destinations, then connect to a Linux shell and continue an existing Herdr session. " +
                        "Talkies never stores your password or sends dictated text to run automatically.",
                    style = MaterialTheme.typography.bodySmall,
                )
                Text("Transport: SSH · Mosh is not configured in this build", style = MaterialTheme.typography.labelSmall)
                Column(
                    modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    if (profiles.isEmpty()) {
                        Card {
                            Text(
                                "No hosts yet. Add your Linux machine’s SSH address to get started.",
                                modifier = Modifier.padding(18.dp),
                            )
                        }
                    }
                    profiles.forEach { profile ->
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                            Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(profile.name, style = MaterialTheme.typography.titleMedium)
                                Text("${profile.username}@${profile.host}:${profile.port}", style = MaterialTheme.typography.bodySmall)
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Button(onClick = {
                                        pendingProfile = profile
                                        password = ""
                                        connectionError = null
                                    }) { Text("Connect") }
                                    OutlinedButton(onClick = {
                                        editId = profile.id
                                        name = profile.name
                                        host = profile.host
                                        port = profile.port.toString()
                                        username = profile.username
                                        formError = null
                                        editing = true
                                    }) { Text("Edit") }
                                    TextButton(onClick = {
                                        store.delete(profile.id)
                                        profiles = store.list()
                                    }) { Text("Remove") }
                                }
                            }
                        }
                    }
                }
            } else {
                val profile = requireNotNull(activeProfile)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text(profile.name, style = MaterialTheme.typography.titleMedium)
                        Text(
                            if (connected) "CONNECTED · HOST VERIFIED" else "DISCONNECTED",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (connected) terminalAccent else MaterialTheme.colorScheme.error,
                        )
                    }
                    OutlinedButton(onClick = { disconnect() }) { Text("Disconnect") }
                }
                if (!connected) {
                    Button(
                        enabled = !connecting,
                        onClick = { pendingProfile = profile; password = "" },
                    ) { Text(if (connecting) "Reconnecting…" else "Reconnect") }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(enabled = connected, onClick = { send("herdr session list\r") }) { Text("Herdr sessions") }
                    OutlinedButton(enabled = connected, onClick = {
                        insertWithoutSubmit(terminalEmulator, "herdr session attach ")
                    }) {
                        Text("Attach session")
                    }
                    OutlinedButton(enabled = connected, onClick = {
                        dictateAfterPermission = true
                        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                            onDictate { text ->
                                val safeText = TerminalInputPolicy.stage(text)
                                if (safeText.isNotEmpty()) insertWithoutSubmit(terminalEmulator, safeText)
                            }
                            dictateAfterPermission = false
                        } else requestMicrophone.launch(Manifest.permission.RECORD_AUDIO)
                    }) { Text("Dictate") }
                    OutlinedButton(enabled = connected, onClick = { send("\u0003") }) { Text("Ctrl-C") }
                    OutlinedButton(enabled = connected, onClick = { send("\u0004") }) { Text("Ctrl-D") }
                }
                Terminal(
                    terminalEmulator = terminalEmulator,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    backgroundColor = terminalBackground,
                    foregroundColor = terminalForeground,
                    keyboardEnabled = connected,
                    showSoftKeyboard = connected,
                    onTerminalTap = { if (connected) { /* Terminal opens the input method on focus. */ } },
                )
                Text(
                    "Dictation stays on-device and is pasted into the remote terminal without Enter. Review before sending. " +
                        "Reconnect asks for your password again.",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }

    if (editing) {
        AlertDialog(
            onDismissRequest = { editing = false },
            title = { Text(if (editId == null) "Add SSH host" else "Edit SSH host") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                    OutlinedTextField(host, { host = it }, label = { Text("Host or IP") }, singleLine = true)
                    OutlinedTextField(
                        port, { port = it.filter(Char::isDigit).take(5) }, label = { Text("Port") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true,
                    )
                    OutlinedTextField(username, { username = it }, label = { Text("SSH username") }, singleLine = true)
                    formError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    runCatching {
                        SshHostProfile(
                            editId ?: UUID.randomUUID().toString(), name.trim(), host.trim(), port.toInt(), username.trim(),
                        ).validate()
                    }.onSuccess { profile ->
                        runCatching { store.save(profile) }
                            .onSuccess { profiles = store.list(); editing = false }
                            .onFailure { formError = it.message }
                    }.onFailure { formError = it.message }
                }) { Text("Save host") }
            },
            dismissButton = { TextButton(onClick = { editing = false }) { Text("Cancel") } },
        )
    }

    pendingProfile?.let { profile ->
        AlertDialog(
            onDismissRequest = { pendingProfile = null; password = "" },
            title = { Text("Connect to ${profile.name}") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Password is used only for this connection and is not saved.")
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("SSH password") },
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                        singleLine = true,
                    )
                    connectionError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            },
            confirmButton = {
                TextButton(enabled = !connecting && password.isNotEmpty(), onClick = {
                    val secret = password.toCharArray()
                    password = ""
                    connect(profile, secret)
                }) {
                    Text(if (connecting) "Connecting…" else "Connect")
                }
            },
            dismissButton = { TextButton(onClick = { pendingProfile = null; password = "" }) { Text("Cancel") } },
        )
    }

    hostTrust?.let { prompt ->
        AlertDialog(
            onDismissRequest = { prompt.answer.complete(false); hostTrust = null },
            title = { Text("Verify SSH host key") },
            text = { Text(prompt.message) },
            confirmButton = {
                TextButton(onClick = { prompt.answer.complete(true); hostTrust = null }) { Text("Trust this key") }
            },
            dismissButton = {
                TextButton(onClick = { prompt.answer.complete(false); hostTrust = null }) { Text("Reject") }
            },
        )
    }
    }
}

private fun insertWithoutSubmit(terminal: org.connectbot.terminal.TerminalEmulator, text: String) {
    // Feed recognized characters through the terminal keyboard path, never adding Enter.
    text.forEach { character -> terminal.dispatchCharacter(0, character) }
}

private data class HostTrustPrompt(val message: String, val answer: CompletableFuture<Boolean>)
