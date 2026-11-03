package com.vpnclient.app.tunnel

import com.vpnclient.app.gen.PrepareResult
import com.vpnclient.app.gen.TunnelModeMsg
import com.vpnclient.app.gen.VpnHostApi
import org.json.JSONArray

/** Forwards the Pigeon calls to the core. Errors become CoreErrorCode values. */
class HostApi(
    private val controller: TunnelController,
    private val requestPermission: suspend () -> PrepareResult,
) : VpnHostApi {
    private suspend fun <T> guarded(call: suspend () -> T): T =
        try {
            call()
        } catch (error: Exception) {
            throw error.toFlutterError()
        }

    override suspend fun prepare(): PrepareResult = requestPermission()

    override suspend fun start(tunnelRequestJson: String) = guarded { controller.start(tunnelRequestJson) }

    override suspend fun update(tunnelRequestJson: String) = guarded { controller.update(tunnelRequestJson) }

    override suspend fun stop() = guarded { controller.stop() }

    override suspend fun setUserMode(mode: TunnelModeMsg) = guarded { controller.setUserMode(mode.wireName()) }

    override suspend fun selectServer(
        group: TunnelModeMsg,
        serverId: String,
    ) = guarded { controller.selectServer(group.wireName(), serverId) }

    override suspend fun urlTest(serverIds: List<String>): String =
        guarded { controller.urlTest(JSONArray(serverIds).toString()) }

    override suspend fun getState(): String = guarded { controller.state() }

    /** S3-03 lists the installed packages. */
    override suspend fun listApps(): List<String> = emptyList()

    override suspend fun forgetLastRequest() = guarded { controller.forgetLastRequest() }
}

fun TunnelModeMsg.wireName(): String =
    when (this) {
        TunnelModeMsg.REGULAR -> "regular"
        TunnelModeMsg.WHITELIST -> "whitelist"
    }
