package com.talkies.android

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.Alignment
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
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
import kotlinx.coroutines.delay
import java.util.UUID
import java.util.concurrent.CompletableFuture

private val terminalBackground = Color(0xFF080D19)
private val terminalForeground = Color(0xFFD9E7FF)
private val terminalAccent = Color(0xFF6FFFE9)

@Composable
internal fun SshCompanionScreen(context: Context, onBack: () -> Unit, onDictate: ((String) -> Unit) -> Unit) {
    val appContext = context.applicationContext
    val store = remember(appContext) { AndroidSshHostProfileStore(appContext) }
    val credentialStore = remember(appContext) { AndroidSshCredentialStore(appContext) }
    val scope = rememberCoroutineScope()
    val mainHandler = remember { Handler(Looper.getMainLooper()) }
    var profiles by remember { mutableStateOf(store.list()) }
    var discoveredHosts by remember { mutableStateOf(emptyList<DiscoveredSshHost>()) }
    var scanningHosts by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf(false) }
    var editId by remember { mutableStateOf<String?>(null) }
    var name by remember { mutableStateOf("") }
    var host by remember { mutableStateOf("") }
    var port by remember { mutableStateOf("22") }
    var username by remember { mutableStateOf("") }
    var formError by remember { mutableStateOf<String?>(null) }
    var pendingProfile by remember { mutableStateOf<SshHostProfile?>(null) }
    var password by remember { mutableStateOf("") }
    var rememberPassword by remember { mutableStateOf(false) }
    var resolvingCredential by remember { mutableStateOf(false) }
    var connecting by remember { mutableStateOf(false) }
    var connectionError by remember { mutableStateOf<String?>(null) }
    var cmuxSocketPassword by remember { mutableStateOf("") }
    var cmuxAuthDraft by remember { mutableStateOf("") }
    var showCmuxAuth by remember { mutableStateOf(false) }
    var hostTrust by remember { mutableStateOf<HostTrustPrompt?>(null) }
    var activeProfile by remember { mutableStateOf<SshHostProfile?>(null) }
    var terminal by remember { mutableStateOf<SshTerminalSession?>(null) }
    var connected by remember { mutableStateOf(false) }
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
    val hostDiscovery = remember(appContext) { SshHostDiscovery(appContext) }
    DisposableEffect(hostDiscovery) { onDispose { hostDiscovery.close() } }
    fun scanHosts() {
        scanningHosts = true
        hostDiscovery.start { discoveredHosts = it }
    }
    LaunchedEffect(hostDiscovery) { scanHosts() }
    LaunchedEffect(scanningHosts) {
        if (scanningHosts) {
            delay(8_000)
            hostDiscovery.stop()
            scanningHosts = false
        }
    }
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

    fun connect(profile: SshHostProfile, secret: CharArray, savePassword: Boolean = false, storedPassword: Boolean = false) {
        if (connecting) {
            secret.fill('\u0000')
            return
        }
        val passwordToStore = if (savePassword) secret.copyOf() else null
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
                val saveError = passwordToStore?.let { savedPassword ->
                    withContext(Dispatchers.IO) {
                        runCatching { credentialStore.save(profile, savedPassword) }.exceptionOrNull()
                    }
                }
                terminal = next
                connected = true
                if (saveError != null) connectionError = "Connected, but the password could not be saved securely."
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
                if (storedPassword && error.message?.contains("auth fail", ignoreCase = true) == true) {
                    credentialStore.delete(profile.id)
                    pendingProfile = profile
                    password = ""
                    rememberPassword = true
                }
            } finally {
                passwordToStore?.fill('\u0000')
                connecting = false
            }
        }
    }

    fun openProfile(profile: SshHostProfile) {
        pendingProfile = profile
        password = ""
        rememberPassword = false
        connectionError = null
        resolvingCredential = true
        scope.launch {
            val saved = withContext(Dispatchers.IO) { runCatching { credentialStore.load(profile) }.getOrNull() }
            resolvingCredential = false
            if (saved != null) {
                pendingProfile = null
                connect(profile, saved, storedPassword = true)
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
        onDictate { text ->
            val clean = TerminalInputPolicy.stage(text)
            if (clean.isNotEmpty()) promptDraft = listOf(promptDraft.trim(), clean).filter(String::isNotEmpty).joinToString(" ")
        }
    }

    fun dictateToShell() {
        dictationForAgent = false
        onDictate { text ->
            val clean = TerminalInputPolicy.stage(text)
            if (clean.isNotEmpty()) insertWithoutSubmit(terminalEmulator, clean)
        }
    }

    TalkiesTheme {
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize()
                .then(if (activeProfile == null) Modifier.verticalScroll(rememberScrollState()) else Modifier)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("TALKIES  /  FIELD LINK", style = MaterialTheme.typography.labelMedium, color = terminalAccent)
                    Text("Remote workspace", style = MaterialTheme.typography.titleLarge)
                }
                TextButton(onClick = { disconnect(); onBack() }) { Text("Close") }
            }

            if (activeProfile == null) {
                Card(
                    shape = RoundedCornerShape(26.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                ) {
                    Box(
                        Modifier.fillMaxWidth()
                            .background(
                                Brush.linearGradient(
                                    listOf(Color(0xFF103D3A), Color(0xFF202448), Color(0xFF171526)),
                                ),
                            )
                            .padding(20.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text("SECURE LINK  /  SSH", style = MaterialTheme.typography.labelLarge, color = terminalAccent)
                                LinkStateBadge(
                                    label = if (scanningHosts) "SCANNING" else if (discoveredHosts.isEmpty()) "STANDBY" else "${discoveredHosts.size} FOUND",
                                    active = scanningHosts || discoveredHosts.isNotEmpty(),
                                )
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Text("Your work,\nwithin reach.", style = MaterialTheme.typography.headlineMedium)
                                    Text(
                                        "Nearby workstations, one secure link away.",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                    Button(
                                        onClick = {
                                            if (scanningHosts) {
                                                hostDiscovery.stop()
                                                scanningHosts = false
                                            } else scanHosts()
                                        },
                                        shape = RoundedCornerShape(16.dp),
                                    ) {
                                        Text(if (scanningHosts) "Stop scan" else "Find nearby machines")
                                    }
                                }
                                DiscoveryRadar(scanning = scanningHosts, modifier = Modifier.size(96.dp))
                            }
                            Text(
                                "Passwords stay encrypted on this device · saving is optional",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                if (discoveredHosts.isNotEmpty()) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("NEARBY MACHINES", style = MaterialTheme.typography.labelLarge, color = terminalAccent)
                        Text("${discoveredHosts.size} found", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        discoveredHosts.forEach { found ->
                            NearbyHostCard(host = found) {
                                val savedProfile = profiles.firstOrNull {
                                    it.host.equals(found.host, ignoreCase = true) && it.port == found.port
                                }
                                val commonUsername = profiles.map { it.username }.distinct().singleOrNull()
                                val profile = savedProfile ?: found.toProfile(commonUsername)
                                if (profile != null) {
                                    if (savedProfile == null) store.save(profile)
                                    profiles = store.list()
                                    openProfile(profile)
                                } else {
                                    editId = null
                                    name = found.name
                                    host = found.host
                                    port = found.port.toString()
                                    username = ""
                                    formError = "Enter the SSH username for this machine."
                                    editing = true
                                }
                            }
                        }
                    }
                } else if (!scanningHosts) {
                    Text(
                        "No SSH services advertised yet. You can still add a host manually; a saved host appears here next time.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("YOUR MACHINES", style = MaterialTheme.typography.titleMedium)
                        Text("Saved secure connections", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    OutlinedButton(onClick = {
                        editId = null
                        name = ""
                        host = ""
                        port = "22"
                        username = ""
                        formError = null
                        editing = true
                    }) { Text("Add host") }
                }
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    if (profiles.isEmpty() && discoveredHosts.isEmpty()) {
                        Card {
                            Text(
                                "No hosts yet. Add your Linux machine’s SSH address to get started.",
                                modifier = Modifier.padding(18.dp),
                            )
                        }
                    }
                    profiles.forEach { profile ->
                        SavedHostCard(
                            profile = profile,
                            onConnect = {
                                openProfile(profile)
                            },
                            onEdit = {
                                editId = profile.id
                                name = profile.name
                                host = profile.host
                                port = profile.port.toString()
                                username = profile.username
                                formError = null
                                editing = true
                            },
                            onRemove = {
                                credentialStore.delete(profile.id)
                                store.delete(profile.id)
                                profiles = store.list()
                            },
                        )
                    }
                }
            } else {
                val profile = requireNotNull(activeProfile)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(profile.name, style = MaterialTheme.typography.titleLarge)
                        Text("${profile.username}@${profile.host}:${profile.port}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        LinkStateBadge(
                            label = when { connecting -> "LINKING"; connected -> "VERIFIED"; else -> "OFFLINE" },
                            active = connected || connecting,
                        )
                        if (connected) TextButton(onClick = { disconnect() }) { Text("Disconnect") }
                    }
                }
                if (!connected) {
                    Button(
                        enabled = !connecting,
                        onClick = { openProfile(profile) },
                    ) { Text(if (connecting) "Reconnecting…" else "Reconnect") }
                }
                Text("WORKSPACE CONTROLS", style = MaterialTheme.typography.labelLarge, color = terminalAccent)
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
                        Text("AGENT SIGNALS", style = MaterialTheme.typography.titleMedium)
                        Text("Herdr + cmux · live host scan", style = MaterialTheme.typography.labelSmall, color = terminalAccent)
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
            onDismissRequest = { pendingProfile = null; password = ""; rememberPassword = false },
            title = { Text("Connect to ${profile.name}") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Passwords are saved only when you choose to remember them. Saved passwords are encrypted with Android Keystore and excluded from device backup.")
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("SSH password") },
                        enabled = !resolvingCredential && !connecting,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                        singleLine = true,
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = rememberPassword, onCheckedChange = { rememberPassword = it })
                        Text("Remember password on this device")
                    }
                    if (resolvingCredential) Text("Checking for a saved password…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    connectionError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            },
            confirmButton = {
                TextButton(enabled = !connecting && password.isNotEmpty(), onClick = {
                    val secret = password.toCharArray()
                    val savePassword = rememberPassword
                    password = ""
                    connect(profile, secret, savePassword = savePassword)
                }) {
                    Text(if (connecting) "Connecting…" else "Connect")
                }
            },
            dismissButton = { TextButton(onClick = { pendingProfile = null; password = ""; rememberPassword = false }) { Text("Cancel") } },
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

@Composable
private fun LinkStateBadge(label: String, active: Boolean) {
    val tint = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
    Surface(
        color = if (active) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(50),
    ) {
        Row(
            Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.size(6.dp).background(tint, RoundedCornerShape(50)))
            Text(label, style = MaterialTheme.typography.labelSmall, color = tint)
        }
    }
}

@Composable
private fun NearbyHostCard(host: DiscoveredSshHost, onConnect: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(start = 14.dp, top = 12.dp, end = 10.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(Modifier.size(42.dp).background(Color(0xFF17383B), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                TalkiesGlyph(TalkiesGlyphKind.SERVER, terminalAccent, Modifier.size(26.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(host.name, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                Text(
                    "${host.username?.let { "$it@" } ?: ""}${host.host}:${host.port}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
                Text("SSH SERVICE FOUND", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
            Button(onClick = onConnect, shape = RoundedCornerShape(14.dp)) { Text("Connect") }
        }
    }
}

@Composable
private fun SavedHostCard(
    profile: SshHostProfile,
    onConnect: () -> Unit,
    onEdit: () -> Unit,
    onRemove: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(20.dp),
    ) {
        Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(42.dp).background(Color(0xFF282448), RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
                    TalkiesGlyph(TalkiesGlyphKind.TERMINAL, MaterialTheme.colorScheme.secondary, Modifier.size(26.dp))
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(profile.name, style = MaterialTheme.typography.titleMedium)
                    Text("${profile.username}@${profile.host}:${profile.port}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                LinkStateBadge("SAVED", active = true)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = onConnect, shape = RoundedCornerShape(14.dp)) { Text("Connect securely") }
                TextButton(onClick = onEdit) { Text("Edit") }
                TextButton(onClick = onRemove) { Text("Remove") }
            }
        }
    }
}

@Composable
private fun DiscoveryRadar(scanning: Boolean, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "discovery-radar")
    val angle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(2200, easing = LinearEasing), RepeatMode.Restart),
        label = "radar-sweep",
    )
    Canvas(modifier) {
        val center = androidx.compose.ui.geometry.Offset(size.width / 2, size.height / 2)
        val radius = size.minDimension * 0.44f
        val lineColor = if (scanning) terminalAccent else Color(0xFF54778B)
        listOf(0.38f, 0.68f, 1f).forEach { fraction ->
            drawCircle(lineColor.copy(alpha = if (scanning) 0.34f else 0.2f), radius * fraction, center, style = Stroke(1.2.dp.toPx()))
        }
        drawLine(lineColor.copy(alpha = 0.28f), androidx.compose.ui.geometry.Offset(center.x - radius, center.y), androidx.compose.ui.geometry.Offset(center.x + radius, center.y), strokeWidth = 1.dp.toPx())
        drawLine(lineColor.copy(alpha = 0.28f), androidx.compose.ui.geometry.Offset(center.x, center.y - radius), androidx.compose.ui.geometry.Offset(center.x, center.y + radius), strokeWidth = 1.dp.toPx())
        rotate(angle, center) {
            drawArc(
                brush = Brush.sweepGradient(listOf(Color.Transparent, terminalAccent.copy(alpha = 0.6f), Color.Transparent), center),
                startAngle = -35f,
                sweepAngle = 70f,
                useCenter = true,
                topLeft = androidx.compose.ui.geometry.Offset(center.x - radius, center.y - radius),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2),
            )
        }
        drawCircle(terminalAccent, radius = 3.dp.toPx(), center = center)
        drawCircle(Color(0xFFB69CFF), radius = 2.dp.toPx(), center = androidx.compose.ui.geometry.Offset(center.x + radius * 0.4f, center.y - radius * 0.45f))
    }
}

private data class HostTrustPrompt(val message: String, val answer: CompletableFuture<Boolean>)
