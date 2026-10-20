package com.talkies.android

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

enum class AgentBridge { HERDR, CMUX }

enum class AgentLifeState { IDLE, WORKING, NEEDS_INPUT, UNKNOWN }

data class HerdrSession(val name: String, val running: Boolean, val isDefault: Boolean)

data class RemoteAgent(
    val bridge: AgentBridge,
    val id: String,
    val name: String,
    val state: AgentLifeState,
    val workspace: String? = null,
    val workspaceId: String? = null,
    val directory: String? = null,
    val title: String? = null,
    val hasDraft: Boolean = false,
    val hasDialog: Boolean = false,
    val sessionName: String? = null,
)

object RemoteAgentPromptPolicy {
    fun refusal(agent: RemoteAgent): String? = when {
        agent.hasDraft -> "There is an unsent draft in the agent. Review it there first."
        agent.hasDialog -> "The agent is asking a question. Handle it before sending another prompt."
        agent.state != AgentLifeState.IDLE -> "The agent is ${agent.state.name.lowercase()}. Read its latest output before sending."
        else -> null
    }
}

/** Strict, read-first decoders for the machine-readable Herdr and cmux interfaces. */
object RemoteAgentJson {
    private val json = Json { ignoreUnknownKeys = true }

    fun herdrSessions(raw: String): List<HerdrSession> {
        val root = json.parseToJsonElement(raw).objectOrNull() ?: return emptyList()
        val envelope = root["result"].objectOrNull() ?: root
        val sessions = envelope["sessions"] as? JsonArray ?: return emptyList()
        return sessions.mapNotNull { element ->
            val item = element.objectOrNull() ?: return@mapNotNull null
            val name = item.string("name")?.takeIf { SESSION_NAME.matches(it) } ?: return@mapNotNull null
            HerdrSession(name, item["running"].boolean() == true, item["default"].boolean() == true)
        }
    }

    fun herdrAgents(raw: String, sessionName: String = "default"): List<RemoteAgent> {
        val root = json.parseToJsonElement(raw).objectOrNull() ?: return emptyList()
        val envelope = root["result"].objectOrNull() ?: root
        val agents = envelope["agents"] as? JsonArray ?: return emptyList()
        return agents.mapNotNull { element ->
            val item = element.objectOrNull() ?: return@mapNotNull null
            val pane = item.string("pane_id") ?: return@mapNotNull null
            if (!HERDR_PANE_ID.matches(pane)) return@mapNotNull null
            val kind = item.string("agent") ?: "Agent"
            RemoteAgent(
                bridge = AgentBridge.HERDR,
                id = pane,
                name = kind.replaceFirstChar { it.uppercase() },
                state = when (item.string("agent_status")?.lowercase()) {
                    "idle", "done" -> AgentLifeState.IDLE
                    "working", "running" -> AgentLifeState.WORKING
                    "blocked", "needsinput", "needs_input" -> AgentLifeState.NEEDS_INPUT
                    else -> AgentLifeState.UNKNOWN
                },
                workspaceId = item.string("workspace_id"),
                directory = item.string("foreground_cwd") ?: item.string("cwd"),
                title = item.string("terminal_title_stripped") ?: item.string("terminal_title"),
                sessionName = sessionName,
            )
        }
    }

    data class CmuxSurface(val id: String, val workspaceId: String, val workspaceTitle: String?, val title: String?)

    fun cmuxSurfaces(raw: String): List<CmuxSurface> {
        val root = json.parseToJsonElement(raw).objectOrNull() ?: return emptyList()
        val windows = root["windows"] as? JsonArray ?: return emptyList()
        return buildList {
            windows.forEach { window ->
                val workspaces = window.objectOrNull()?.get("workspaces") as? JsonArray ?: return@forEach
                workspaces.forEach { workspace ->
                    val workspaceObject = workspace.objectOrNull() ?: return@forEach
                    val workspaceId = workspaceObject.string("id") ?: return@forEach
                    val workspaceName = workspaceObject.string("title")
                    val panes = workspaceObject["panes"] as? JsonArray ?: return@forEach
                    panes.forEach { pane ->
                        val surfaces = pane.objectOrNull()?.get("surfaces") as? JsonArray ?: return@forEach
                        surfaces.forEach { surface ->
                            val item = surface.objectOrNull() ?: return@forEach
                            if ((item.string("type") ?: "terminal") == "terminal") {
                                item.string("id")?.let { add(CmuxSurface(it, workspaceId, workspaceName, item.string("title"))) }
                            }
                        }
                    }
                }
            }
        }
    }

    fun cmuxAgent(surface: CmuxSurface, raw: String): RemoteAgent? {
        val root = json.parseToJsonElement(raw).objectOrNull() ?: return null
        val state = root["result"].objectOrNull() ?: root
        if (state["agent"].boolean() != true) return null
        val lifecycle = state.string("lifecycle")?.lowercase()
        return RemoteAgent(
            bridge = AgentBridge.CMUX,
            id = surface.id,
            name = surface.title?.takeIf(String::isNotBlank) ?: surface.workspaceTitle ?: "Agent",
            state = when (lifecycle) {
                "idle", "done" -> AgentLifeState.IDLE
                "running", "working" -> AgentLifeState.WORKING
                "needsinput", "needs_input" -> AgentLifeState.NEEDS_INPUT
                else -> if (state["waiting_on_human"].boolean() == true) AgentLifeState.NEEDS_INPUT else AgentLifeState.UNKNOWN
            },
            workspace = surface.workspaceTitle,
            workspaceId = surface.workspaceId,
            title = surface.title,
            hasDraft = state.string("state") == "draft",
            hasDialog = state.string("state") == "dialog",
        )
    }

    fun shellQuote(value: String): String = "'" + value.replace("'", "'\\''") + "'"

    private fun JsonElement?.objectOrNull(): JsonObject? = this as? JsonObject
    private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull
    private fun JsonElement?.boolean(): Boolean? = runCatching { this?.jsonPrimitive?.content?.toBooleanStrict() }.getOrNull()

    private val HERDR_PANE_ID = Regex("w[0-9]+:p[0-9]+")
    private val SESSION_NAME = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,63}")
}
