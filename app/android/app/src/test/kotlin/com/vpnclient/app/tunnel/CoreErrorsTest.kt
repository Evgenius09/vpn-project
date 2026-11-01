package com.vpnclient.app.tunnel

import com.vpnclient.app.gen.TunnelModeMsg
import org.junit.Assert.assertEquals
import org.junit.Test

class CoreErrorsTest {
    @Test
    fun readsTheCodeOfACoreError() {
        assertEquals("start_failed", coreErrorCode("start_failed: tun busy"))
        assertEquals("config_invalid", coreErrorCode("config_invalid: malformed request"))
    }

    @Test
    fun everyContractCodeSurvives() {
        val codes =
            listOf(
                "config_invalid",
                "start_failed",
                "no_servers_in_group",
                "permission_denied",
                "tun_failed",
                "revoked",
                "service_unavailable",
                "ipc_version_mismatch",
                "internal",
            )
        for (code in codes) {
            assertEquals(code, coreErrorCode("$code: detail"))
        }
    }

    @Test
    fun anythingElseIsInternal() {
        assertEquals("internal", coreErrorCode("close engine: broken pipe"))
        assertEquals("internal", coreErrorCode(""))
        assertEquals("internal", coreErrorCode(null))
    }

    @Test
    fun errorsKeepTheirMessage() {
        val error = IllegalStateException("revoked: by another app").toFlutterError()
        assertEquals("revoked", error.code)
        assertEquals("revoked: by another app", error.message)
    }

    @Test
    fun modesUseTheirWireNames() {
        assertEquals("regular", TunnelModeMsg.REGULAR.wireName())
        assertEquals("whitelist", TunnelModeMsg.WHITELIST.wireName())
    }
}
