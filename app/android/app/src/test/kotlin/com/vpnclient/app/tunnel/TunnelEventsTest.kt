package com.vpnclient.app.tunnel

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TunnelEventsTest {
    private fun state(status: String) =
        """{"type":"state","at":"2026-11-01T10:00:00Z","state":{"status":"$status","userMode":"regular","effectiveMode":"regular"}}"""

    @Test
    fun readsTheStatusOfAStateEvent() {
        assertEquals("connected", tunnelStatusOf(state("connected")))
    }

    @Test
    fun otherEventsHaveNoStatus() {
        val traffic = """{"type":"traffic","at":"2026-11-01T10:00:00Z","traffic":{"upBps":1,"downBps":2,"upTotal":3,"downTotal":4}}"""
        assertNull(tunnelStatusOf(traffic))
    }

    @Test
    fun theNotificationFollowsTheTunnel() {
        assertEquals(TunnelNotice.CONNECTING, noticeOf("connecting"))
        assertEquals(TunnelNotice.CONNECTED, noticeOf("connected"))
        assertEquals(TunnelNotice.DISCONNECTING, noticeOf("disconnecting"))
    }

    @Test
    fun aStoppedTunnelChangesNoNotification() {
        assertNull(noticeOf("disconnected"))
        assertNull(noticeOf("error"))
        assertNull(noticeOf("unknown"))
    }

    @Test
    fun aRevokedTunnelReportsACoreEvent() {
        val event = JSONObject(revokedEvent(1_793_577_600_000))
        assertEquals("error", event.getString("type"))
        assertEquals("2026-11-02T00:00:00Z", event.getString("at"))
        assertEquals("revoked", event.getJSONObject("error").getString("code"))
    }

    @Test
    fun anIncludeListWinsOverTheExcludeList() {
        val rules = packageRules(listOf("org.a"), listOf("com.vpnclient.app"))
        assertEquals(listOf("org.a"), rules.allowed)
        assertEquals(emptyList<String>(), rules.disallowed)
    }

    @Test
    fun withoutAnIncludeListTheExcludeListApplies() {
        val rules = packageRules(emptyList(), listOf("org.a", "com.vpnclient.app"))
        assertEquals(emptyList<String>(), rules.allowed)
        assertEquals(listOf("org.a", "com.vpnclient.app"), rules.disallowed)
    }
}
