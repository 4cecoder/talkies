package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RemoteAgentJsonTest {
    @Test
    fun parsesHerdrAgentsAndKeepsUnknownStatesUnsendable() {
        val agents = RemoteAgentJson.herdrAgents(
            """{"id":"cli:agent:list","result":{"agents":[
                {"agent":"codex","agent_status":"blocked","pane_id":"w1:p2","cwd":"/src/app","terminal_title_stripped":"Review"},
                {"agent":"claude","agent_status":"idle","pane_id":"w1:p4","foreground_cwd":"/src/api"},
                {"agent":"bad","agent_status":"idle","pane_id":"--help"}
            ]}}"""
        )
        assertEquals(2, agents.size)
        assertEquals("Codex", agents[0].name)
        assertEquals(AgentLifeState.NEEDS_INPUT, agents[0].state)
        assertEquals("Review", agents[0].title)
        assertEquals("/src/api", agents[1].directory)
        assertFalse(agents.any { it.id == "--help" })
    }

    @Test
    fun parsesOnlySafeHerdrSessionLabels() {
        val sessions = RemoteAgentJson.herdrSessions(
            """{"sessions":[{"name":"default","running":true,"default":true},
                {"name":"work-2","running":true,"default":false},
                {"name":"$(bad)","running":true,"default":false}]}"""
        )
        assertEquals(listOf("default", "work-2"), sessions.map { it.name })
        assertTrue(sessions.first().isDefault)
    }

    @Test
    fun listsOnlyCmuxSurfacesDetectedAsAgentsAndPreservesDraftGuard() {
        val surfaces = RemoteAgentJson.cmuxSurfaces(
            """{"windows":[{"workspaces":[{"id":"w","title":"Fyle","panes":[{"surfaces":[
                {"id":"surface-a","type":"terminal","title":"Codex"},
                {"id":"surface-b","type":"browser","title":"Docs"}
            ]}]}]}]}"""
        )
        assertEquals(1, surfaces.size)
        assertEquals("surface-a", surfaces.single().id)
        assertEquals("w", surfaces.single().workspaceId)
        val agent = RemoteAgentJson.cmuxAgent(
            surfaces.single(),
            """{"agent":true,"state":"draft","lifecycle":"idle","waiting_on_human":false}"""
        )
        assertEquals(AgentLifeState.IDLE, agent?.state)
        assertTrue(agent?.hasDraft == true)
        assertEquals(null, RemoteAgentJson.cmuxAgent(surfaces.single().copy(id = "surface-b"), """{"agent":false}"""))
    }

    @Test
    fun shellQuotingCannotTurnPromptTextIntoAnotherCommand() {
        assertEquals("'say '\\''hi'\\''; rm -rf /'", RemoteAgentJson.shellQuote("say 'hi'; rm -rf /"))
    }

    @Test
    fun promptPolicyRefusesUncertainAndHumanInputStates() {
        val base = RemoteAgent(AgentBridge.HERDR, "w1:p1", "Codex", AgentLifeState.IDLE)
        assertEquals(null, RemoteAgentPromptPolicy.refusal(base))
        assertTrue(RemoteAgentPromptPolicy.refusal(base.copy(state = AgentLifeState.UNKNOWN))!!.contains("unknown"))
        assertTrue(RemoteAgentPromptPolicy.refusal(base.copy(hasDraft = true))!!.contains("draft"))
        assertTrue(RemoteAgentPromptPolicy.refusal(base.copy(hasDialog = true))!!.contains("question"))
    }
}
