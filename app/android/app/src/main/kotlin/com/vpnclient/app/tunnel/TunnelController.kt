package com.vpnclient.app.tunnel

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.vpnclient.core.bind.Core
import com.vpnclient.core.bind.EventSink
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Owns the single core of the process. It outlives the UI, so the tunnel keeps
 * running when the activity goes away.
 */
class TunnelController private constructor(private val context: Context) : EventSink {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val platform = VpnPlatform(context)
    private val core = Core(platform, this, File(context.filesDir, "core").path)

    private var pendingRequest: String? = null
    private var pendingStart: CompletableDeferred<Unit>? = null

    /** Receives CoreEvent JSON on the main thread. */
    @Volatile
    var listener: ((String) -> Unit)? = null

    override fun onEvent(coreEventJSON: String) {
        mainHandler.post { listener?.invoke(coreEventJSON) }
    }

    suspend fun start(tunnelRequestJson: String) {
        val started = CompletableDeferred<Unit>()
        pendingRequest = tunnelRequestJson
        pendingStart = started
        ContextCompat.startForegroundService(context, Intent(context, TunnelService::class.java))
        started.await()
    }

    /** Runs on the service, because the core may need its VPN powers. */
    internal fun startOn(service: TunnelService) {
        val request = pendingRequest
        val started = pendingStart
        pendingRequest = null
        pendingStart = null
        if (request == null || started == null) {
            service.finish()
            return
        }
        platform.service = service
        try {
            core.start(request)
            started.complete(Unit)
        } catch (error: Exception) {
            platform.service = null
            service.finish()
            started.completeExceptionally(error)
        }
    }

    suspend fun stop() {
        withContext(Dispatchers.IO) { core.stop() }
        platform.service?.finish()
        platform.service = null
    }

    suspend fun update(tunnelRequestJson: String) = withContext(Dispatchers.IO) { core.update(tunnelRequestJson) }

    suspend fun setUserMode(mode: String) = withContext(Dispatchers.IO) { core.setUserMode(mode) }

    suspend fun selectServer(
        group: String,
        serverId: String,
    ) = withContext(Dispatchers.IO) { core.selectServer(group, serverId) }

    suspend fun urlTest(serverIdsJson: String): String = withContext(Dispatchers.IO) { core.urlTest(serverIdsJson) }

    fun state(): String = core.state()

    companion object {
        @Volatile
        private var instance: TunnelController? = null

        fun get(context: Context): TunnelController =
            instance ?: synchronized(this) {
                instance ?: TunnelController(context.applicationContext).also { instance = it }
            }
    }
}
