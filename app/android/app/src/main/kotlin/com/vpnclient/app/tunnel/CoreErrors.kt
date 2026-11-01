package com.vpnclient.app.tunnel

import com.vpnclient.app.gen.FlutterError

private const val INTERNAL = "internal"

private val CORE_ERROR_CODES =
    setOf(
        "config_invalid",
        "start_failed",
        "no_servers_in_group",
        "permission_denied",
        "tun_failed",
        "revoked",
        "service_unavailable",
        "ipc_version_mismatch",
        INTERNAL,
    )

/**
 * Reads the CoreErrorCode from a gomobile exception. The core formats these
 * errors as "code: message", and any other error counts as internal.
 */
fun coreErrorCode(message: String?): String {
    val code = message.orEmpty().substringBefore(':').trim()
    return if (code in CORE_ERROR_CODES) code else INTERNAL
}

fun Throwable.toFlutterError(): FlutterError = FlutterError(coreErrorCode(message), message, null)
