package com.talkies.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID

internal data class RemoteAgentSnapshot(val agents: List<RemoteAgent>, val notes: List<String>)

/** Runs only fixed, narrowly scoped Herdr/cmux CLI operations through the authenticated SSH session. */
internal object RemoteAgentBridge {
    suspend fun herdrSessions(session: SshTerminalSession): List<HerdrSession> = withContext(Dispatchers.IO) {
        RemoteAgentJson.herdrSessions(session.runCommand(herdr("session list --json")))
    }

    suspend fun discover(
        session: SshTerminalSession,
        herdrSession: String,
        cmuxPassword: String = "",
    ): RemoteAgentSnapshot = withContext(Dispatchers.IO) {
        val agents = mutableListOf<RemoteAgent>()
        val notes = mutableListOf<String>()
        runCatching { session.runCommand(herdr("agent list", herdrSession)) }
            .onSuccess { agents += RemoteAgentJson.herdrAgents(it, herdrSession) }
            .onFailure { notes += "Herdr unavailable: ${it.message ?: "could not query agent state"}" }

        val cmuxSurfaces = runCatching {
            cmuxCommand(session, "--json --id-format uuids tree --all", cmuxPassword)
        }.getOrElse {
            notes += "cmux unavailable: ${it.message ?: "could not query agent state"}"
            null
        }
        cmuxSurfaces?.let { tree ->
            for (surface in RemoteAgentJson.cmuxSurfaces(tree).take(80)) {
                if (runCatching { UUID.fromString(surface.id) }.isFailure) continue
                val args = "rpc surface.input_state ${RemoteAgentJson.shellQuote("{\"surface_id\":\"${surface.id}\"}")}"
                try {
                    RemoteAgentJson.cmuxAgent(surface, cmuxCommand(session, args, cmuxPassword))?.let(agents::add)
                } catch (error: Exception) {
                    notes += "cmux agent status unavailable: ${error.message ?: "socket request failed"}"
                    break
                }
            }
        }
        RemoteAgentSnapshot(
            agents = agents.distinctBy { Triple(it.bridge, it.sessionName, it.id) }.sortedWith(
                compareBy<RemoteAgent> {
                    when (it.state) {
                        AgentLifeState.NEEDS_INPUT -> 0
                        AgentLifeState.WORKING -> 1
                        AgentLifeState.IDLE -> 2
                        AgentLifeState.UNKNOWN -> 3
                    }
                }.thenBy { it.name.lowercase() }
            ),
            notes = notes,
        )
    }

    suspend fun read(session: SshTerminalSession, agent: RemoteAgent, cmuxPassword: String = ""): String = withContext(Dispatchers.IO) {
        when (agent.bridge) {
            AgentBridge.HERDR -> session.runCommand(herdr(
                "agent read ${RemoteAgentJson.shellQuote(requireHerdrId(agent.id))} --source visible --lines 60",
                agent.sessionName ?: "default",
            ))
            AgentBridge.CMUX -> {
                val workspace = requireNotNull(agent.workspaceId) { "cmux did not provide a workspace ID." }
                requireCmuxId(agent.id)
                requireCmuxId(workspace)
                cmuxCommand(session, "read-screen --workspace ${RemoteAgentJson.shellQuote(workspace)} --surface ${RemoteAgentJson.shellQuote(agent.id)} --lines 60", cmuxPassword)
            }
        }.trim().takeLast(12_000)
    }

    suspend fun sendPrompt(
        session: SshTerminalSession,
        agent: RemoteAgent,
        text: String,
        cmuxPassword: String = "",
    ): String = withContext(Dispatchers.IO) {
        require(text.isNotBlank()) { "Write or dictate a prompt first." }
        when (agent.bridge) {
            AgentBridge.HERDR -> {
                requireHerdrId(agent.id)
                val herdrSession = agent.sessionName ?: "default"
                val fresh = RemoteAgentJson.herdrAgents(session.runCommand(herdr("agent list", herdrSession)), herdrSession)
                    .firstOrNull { it.id == agent.id }
                    ?: error("Herdr no longer lists this agent. Refresh and inspect before retrying.")
                RemoteAgentPromptPolicy.refusal(fresh)?.let { error(it) }
                session.runCommand(
                    herdr(
                        "agent prompt ${RemoteAgentJson.shellQuote(agent.id)} ${RemoteAgentJson.shellQuote(text)}",
                        herdrSession,
                    )
                )
            }
            AgentBridge.CMUX -> {
                requireCmuxId(agent.id)
                val stateJson = cmuxCommand(
                    session,
                    "rpc surface.input_state ${RemoteAgentJson.shellQuote("{\"surface_id\":\"${agent.id}\"}")}",
                    cmuxPassword,
                )
                val latest = RemoteAgentJson.cmuxAgent(
                    RemoteAgentJson.CmuxSurface(agent.id, requireNotNull(agent.workspaceId), agent.workspace, agent.title),
                    stateJson,
                ) ?: error("cmux no longer detects an agent on this surface. Nothing was sent.")
                RemoteAgentPromptPolicy.refusal(latest)?.let { error(it) }
                cmuxCommand(
                    session,
                    "agent message ${RemoteAgentJson.shellQuote(agent.id)} --from Talkies -",
                    cmuxPassword,
                    text.toByteArray(Charsets.UTF_8),
                )
            }
        }.trim().ifEmpty { "Prompt sent to ${agent.name}." }
    }

    private fun requireHerdrId(id: String): String {
        require(Regex("w[0-9]+:p[0-9]+").matches(id)) { "Herdr pane changed. Refresh agents and choose it again." }
        return id
    }

    private fun requireCmuxId(id: String) {
        require(runCatching { UUID.fromString(id) }.isSuccess) { "Invalid cmux handle. Refresh agents and choose it again." }
    }

    private fun herdr(command: String, sessionName: String = "default"): String {
        require(Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,63}").matches(sessionName)) { "Invalid Herdr session name." }
        return "sh -lc ${RemoteAgentJson.shellQuote("exec herdr --session ${RemoteAgentJson.shellQuote(sessionName)} $command")}"
    }

    private fun cmux(arguments: String): String {
        val bundled = "/Applications/cmux.app/Contents/Resources/bin/cmux"
        val inner = "if command -v cmux >/dev/null 2>&1; then exec cmux $arguments; elif [ -x $bundled ]; then exec $bundled $arguments; else echo 'cmux CLI not found' >&2; exit 127; fi"
        return "sh -lc ${RemoteAgentJson.shellQuote(inner)}"
    }

    private fun cmuxCommand(
        session: SshTerminalSession,
        arguments: String,
        password: String,
        standardInput: ByteArray? = null,
    ): String = session.runCommand(
        cmux(arguments),
        standardInput,
        if (password.isBlank()) emptyMap() else mapOf("CMUX_SOCKET_PASSWORD" to password),
    )
}
