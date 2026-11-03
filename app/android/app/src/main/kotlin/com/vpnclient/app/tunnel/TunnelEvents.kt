package com.vpnclient.app.tunnel

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

/** What the foreground notification says. A stopped tunnel has no notification. */
enum class TunnelNotice { CONNECTING, CONNECTED, DISCONNECTING }

/** Returns the status of a state event, or null for any other event. */
fun tunnelStatusOf(coreEventJson: String): String? {
    val event = JSONObject(coreEventJson)
    if (event.optString("type") != "state") {
        return null
    }
    return event.optJSONObject("state")?.optString("status")
}

fun noticeOf(status: String): TunnelNotice? =
    when (status) {
        "connecting" -> TunnelNotice.CONNECTING
        "connected" -> TunnelNotice.CONNECTED
        "disconnecting" -> TunnelNotice.DISCONNECTING
        else -> null
    }

/**
 * Builds the CoreEvent for a tunnel the system took away. The host reports it,
 * because only VpnService learns about the revocation and the frozen core
 * surface has no call for it.
 */
fun revokedEvent(atEpochMillis: Long): String {
    val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.ROOT)
    format.timeZone = TimeZone.getTimeZone("UTC")
    return JSONObject()
        .put("type", "error")
        .put("at", format.format(Date(atEpochMillis)))
        .put("error", JSONObject().put("code", "revoked").put("message", "another app took over the VPN"))
        .toString()
}

data class PackageRules(
    val allowed: List<String>,
    val disallowed: List<String>,
)

/**
 * VpnService.Builder refuses to mix both lists. An include list already leaves
 * out everything else, the app itself included.
 */
fun packageRules(
    include: List<String>,
    exclude: List<String>,
): PackageRules =
    if (include.isNotEmpty()) {
        PackageRules(include, emptyList())
    } else {
        PackageRules(emptyList(), exclude)
    }
