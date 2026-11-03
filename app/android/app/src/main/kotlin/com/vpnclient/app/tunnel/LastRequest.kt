package com.vpnclient.app.tunnel

import java.io.File

/**
 * Keeps the last accepted TunnelRequest, because always-on starts the service
 * without one. It holds server secrets, so it lives in the no-backup directory.
 */
class LastRequest(
    directory: File,
) {
    private val file = File(directory, "last_request.json")
    private val temporary = File(directory, "last_request.json.tmp")

    fun read(): String? = if (file.exists()) file.readText() else null

    fun write(request: String) {
        temporary.writeText(request)
        temporary.renameTo(file)
    }
}
