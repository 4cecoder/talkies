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
import androidx.compose.foundation.horizontalScroll
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
    var cmuxSocketPassword by remember { mutableStateOf("") }
    var cmuxAuthDraft by remember { mutableStateOf("") }
    var showCmuxAuth by remember { mutableStateOf(false) }
    var hostTrust by remember { mutableStateOf<HostTrustPrompt?>(null) }
    var activeProfile by remember { mutableStateOf<SshHostProfile?>(null) }
    var terminal by remember { mutableStateOf<SshTerminalSession?>(null) }
    var connected by remember { mutableStateOf(false) }
    var dictateAfterPermission by remember { mutableStateOf(false) }
    var agents by remember { mutableStateOf<List<RemoteAgent>>(emptyList()) }
    var herdrSessions by remember { mutableStateOf(listOf(HerdrSession("default", true, true))) }
    var selectedHerdrSession by remember { mutableStateOf("default") }
    var chooseHerdrSession by remember { mutableStateOf(false) }
    var selectedAgent by remember { mutableStateOf<RemoteAgent?>(null) }
    var agentOutput by remember { mutableStateOf("") }
    var promptDraft by remember { mutableStateOf("") }
    var agentBusy by remember { mutableStateOf(false) }
    var agentError by remember { mutableStateOf<String?>(null) }
    var confirmPrompt by remember { mutableStateOf(false) }
    var dictationForAgent by remember { mutableStateOf(true) }
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
                if (safeText.isNotEmpty()) {
                    if (dictationForAgent && selectedAgent != null) {
                        promptDraft = listOf(promptDraft.trim(), safeText).filter(String::isNotEmpty).joinToString(" ")
                    } else insertWithoutSubmit(terminalEmulator, safeText)
                }
            }
        }
        dictateAfterPermission = false
    }

    suspend fun refreshAgents(session: SshTerminalSession) {
        if (agentBusy) return
        agentBusy = true
        agentError = null
        try {
            val snapshot = RemoteAgentBridge.discover(session, selectedHerdrSession, cmuxSocketPassword)
            agents = snapshot.agents
            val selected = selectedAgent?.let { old -> agents.firstOrNull { it.bridge == old.bridge && it.id == old.id } }
            selectedAgent = selected
            if (selected == null) {
                agentOutput = ""
                promptDraft = ""
            }
            agentError = snapshot.notes.takeIf { snapshot.agents.isEmpty() }?.joinToString(" · ")
        } catch (error: Exception) {
            agentError = error.message ?: "Could not inspect remote agents."
        } finally {
            agentBusy = false
        }
    }

    fun connect(profile: SshHostProfile, secret: CharArray) {
        if (connecting) return
        connecting = true
        connectionError = null
        activeProfile = profile
        terminal?.close()
        terminal = null
        cmuxSocketPassword = ""
        cmuxAuthDraft = ""
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
                agents = emptyList()
                selectedAgent = null
                agentOutput = ""
                herdrSessions = runCatching { RemoteAgentBridge.herdrSessions(next).filter { it.running } }
                    .getOrDefault(emptyList()).ifEmpty { listOf(HerdrSession("default", true, true)) }
                selectedHerdrSession = herdrSessions.firstOrNull { it.isDefault }?.name ?: herdrSessions.first().name
                scope.launch { refreshAgents(next) }
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
        cmuxSocketPassword = ""
        cmuxAuthDraft = ""
        showCmuxAuth = false
    }

    fun send(data: String) {
        val active = terminal ?: return
        scope.launch(Dispatchers.IO) {
            runCatching { active.send(data) }
                .onFailure { error -> mainHandler.post { connectionError = error.message } }
        }
    }

    fun inspect(agent: RemoteAgent) {
        if (selectedAgent?.let { it.bridge != agent.bridge || it.id != agent.id } == true) promptDraft = ""
        selectedAgent = agent
        agentOutput = "Loading recent activity…"
        agentError = null
        scope.launch {
            try {
                agentOutput = RemoteAgentBridge.read(requireNotNull(terminal), agent, cmuxSocketPassword).ifBlank { "No recent output." }
            } catch (error: Exception) {
                agentError = error.message ?: "Could not read this agent."
                agentOutput = ""
            }
        }
    }

    fun dictatePrompt() {
        if (selectedAgent == null) {
            agentError = "Choose an agent and inspect its current output before dictating a prompt."
            return
        }
        dictationForAgent = true
        dictateAfterPermission = true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            onDictate { text ->
                val clean = TerminalInputPolicy.stage(text)
                if (clean.isNotEmpty()) promptDraft = listOf(promptDraft.trim(), clean).filter(String::isNotEmpty).joinToString(" ")
            }
            dictateAfterPermission = false
        } else requestMicrophone.launch(Manifest.permission.RECORD_AUDIO)
    }

    fun dictateToShell() {
        dictationForAgent = false
        dictateAfterPermission = true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            onDictate { text ->
                val clean = TerminalInputPolicy.stage(text)
                if (clean.isNotEmpty()) insertWithoutSubmit(terminalEmulator, clean)
            }
            dictateAfterPermission = false
        } else requestMicrophone.launch(Manifest.permission.RECORD_AUDIO)
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
                Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(enabled = connected, onClick = { send("herdr session list\r") }) { Text("Herdr sessions") }
                    OutlinedButton(enabled = connected, onClick = { insertWithoutSubmit(terminalEmulator, "herdr session attach ") }) {
                        Text("Attach in shell")
                    }
                    OutlinedButton(enabled = connected, onClick = { dictateToShell() }) { Text("Voice to shell") }
                    OutlinedButton(enabled = connected, onClick = { dictatePrompt() }) { Text("Dictate prompt") }
                    OutlinedButton(enabled = connected, onClick = { send("\u0003") }) { Text("Ctrl-C") }
                    OutlinedButton(enabled = connected, onClick = { send("\u0004") }) { Text("Ctrl-D") }
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text("AGENT INBOX", style = MaterialTheme.typography.titleMedium)
                        Text("Herdr · cmux · live state", style = MaterialTheme.typography.labelSmall, color = terminalAccent)
                    }
                    Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        OutlinedButton(enabled = connected, onClick = { cmuxAuthDraft = cmuxSocketPassword; showCmuxAuth = true }) {
                            Text("cmux access")
                        }
                        OutlinedButton(enabled = connected && herdrSessions.size > 1, onClick = { chooseHerdrSession = true }) {
                            Text("Herdr · $selectedHerdrSession")
                        }
                        OutlinedButton(enabled = connected && !agentBusy, onClick = {
                            terminal?.let { session -> scope.launch { refreshAgents(session) } }
                        }) { Text(if (agentBusy) "Scanning…" else "Refresh") }
                    }
                }
                if (agents.isEmpty()) {
                    Text(
                        if (agentBusy) "Looking for Herdr and cmux agents on this host…"
                        else "No detected agents yet. Herdr or cmux must be installed and running on the connected host.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Column(
                    modifier = Modifier.weight(if (selectedAgent == null) 0.65f else 0.42f).fillMaxWidth().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    agents.forEach { agent ->
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 7.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text("${agent.name}  ·  ${agent.bridge.name}", style = MaterialTheme.typography.titleSmall)
                                    Text(
                                        "${agentStateLabel(agent.state)}${agent.directory?.let { "  ·  $it" } ?: ""}" +
                                            if (agent.hasDraft) "  ·  draft open" else if (agent.hasDialog) "  ·  dialog open" else "",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = if (agent.state == AgentLifeState.NEEDS_INPUT) MaterialTheme.colorScheme.error else terminalForeground,
                                        maxLines = 1,
                                    )
                                    agent.title?.let { Text(it, style = MaterialTheme.typography.bodySmall, maxLines = 1) }
                                }
                                TextButton(onClick = { inspect(agent) }) { Text(if (selectedAgent == agent) "Selected" else "Read") }
                            }
                        }
                    }
                }
                agentError?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
                if (selectedAgent != null) {
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF0A1222))) {
                        Column(Modifier.fillMaxWidth().padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("RECENT · ${selectedAgent?.name}", style = MaterialTheme.typography.labelLarge, color = terminalAccent)
                            Text(agentOutput.ifBlank { "Read an agent to inspect its recent output." }, style = MaterialTheme.typography.bodySmall, maxLines = 6)
                        }
                    }
                    OutlinedTextField(
                        value = promptDraft,
                        onValueChange = { promptDraft = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Prompt ${selectedAgent?.name ?: "agent"} · review before sending") },
                        minLines = 2,
                        maxLines = 3,
                    )
                    Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(enabled = connected, onClick = { dictatePrompt() }) { Text("Add voice") }
                        Button(
                            enabled = connected && !agentBusy && promptDraft.isNotBlank() &&
                                selectedAgent?.let { RemoteAgentPromptPolicy.refusal(it) == null } == true,
                            onClick = { confirmPrompt = true },
                        ) { Text("Review & send") }
                        TextButton(onClick = { selectedAgent = null; agentOutput = ""; promptDraft = "" }) { Text("Close") }
                    }
                }
                Terminal(
                    terminalEmulator = terminalEmulator,
                    modifier = Modifier.weight(if (selectedAgent == null) 1.5f else 0.9f).fillMaxWidth(),
                    backgroundColor = terminalBackground,
                    foregroundColor = terminalForeground,
                    keyboardEnabled = connected,
                    showSoftKeyboard = connected,
                    onTerminalTap = { if (connected) { /* Terminal opens the input method on focus. */ } },
                )
                Text(
                    "Voice prompts stay on-device until you choose an agent and send. Shell dictation is staged without Enter. " +
                        "No dictated prompt is saved to history.",
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

    if (confirmPrompt) {
        val target = selectedAgent
        AlertDialog(
            onDismissRequest = { confirmPrompt = false },
            title = { Text("Send prompt to ${target?.name ?: "agent"}?") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("This submits text to the selected coding agent. Talkies will not type it into a shell.")
                    Text(promptDraft.take(1200), style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = {
                TextButton(enabled = target != null && !agentBusy, onClick = {
                    val agent = target ?: return@TextButton
                    confirmPrompt = false
                    agentBusy = true
                    agentError = null
                    scope.launch {
                        try {
                            agentOutput = RemoteAgentBridge.sendPrompt(requireNotNull(terminal), agent, promptDraft, cmuxSocketPassword)
                            promptDraft = ""
                        } catch (error: Exception) {
                            agentError = "Prompt delivery was not confirmed. Read the agent before retrying to avoid duplicates. " +
                                (error.message ?: "Refresh and inspect the agent first.")
                        } finally {
                            agentBusy = false
                        }
                        terminal?.let { refreshAgents(it) }
                    }
                }) { Text("Send prompt") }
            },
            dismissButton = { TextButton(onClick = { confirmPrompt = false }) { Text("Keep editing") } },
        )
    }

    if (chooseHerdrSession) {
        AlertDialog(
            onDismissRequest = { chooseHerdrSession = false },
            title = { Text("Choose Herdr session") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    herdrSessions.forEach { session ->
                        OutlinedButton(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = {
                                selectedHerdrSession = session.name
                                selectedAgent = null
                                agentOutput = ""
                                promptDraft = ""
                                chooseHerdrSession = false
                                terminal?.let { current -> scope.launch { refreshAgents(current) } }
                            },
                        ) { Text("${session.name}${if (session.isDefault) " · default" else ""}") }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { chooseHerdrSession = false }) { Text("Close") } },
        )
    }

    if (showCmuxAuth) {
        AlertDialog(
            onDismissRequest = { showCmuxAuth = false; cmuxAuthDraft = "" },
            title = { Text("cmux remote access") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Set cmux Settings → Automation to Password mode. This password is held only while this SSH companion screen is open and sent in an SSH environment request. Your SSH server must allow CMUX_SOCKET_PASSWORD with AcceptEnv.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    OutlinedTextField(
                        value = cmuxAuthDraft,
                        onValueChange = { cmuxAuthDraft = it.filterNot { char -> char == '\n' || char == '\r' || char == '\u0000' }.take(4096) },
                        label = { Text("cmux socket password") },
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        singleLine = true,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    cmuxSocketPassword = cmuxAuthDraft
                    cmuxAuthDraft = ""
                    showCmuxAuth = false
                    terminal?.let { session -> scope.launch { refreshAgents(session) } }
                }) { Text("Use for this connection") }
            },
            dismissButton = { TextButton(onClick = { showCmuxAuth = false; cmuxAuthDraft = "" }) { Text("Cancel") } },
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

private fun agentStateLabel(state: AgentLifeState): String = when (state) {
    AgentLifeState.IDLE -> "READY"
    AgentLifeState.WORKING -> "WORKING"
    AgentLifeState.NEEDS_INPUT -> "NEEDS YOU"
    AgentLifeState.UNKNOWN -> "STATE UNKNOWN"
}

private data class HostTrustPrompt(val message: String, val answer: CompletableFuture<Boolean>)
