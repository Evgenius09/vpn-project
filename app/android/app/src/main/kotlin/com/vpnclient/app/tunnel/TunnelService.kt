package com.vpnclient.app.tunnel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.vpnclient.app.R
import com.vpnclient.core.libbox.TunOptions
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** Owns the TUN and keeps the process alive while the tunnel runs. */
class TunnelService : VpnService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val controller: TunnelController
        get() = TunnelController.get(this)

    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            scope.launch { controller.stop() }
            return START_NOT_STICKY
        }
        goForeground()
        val alwaysOn = intent?.action == SERVICE_INTERFACE
        scope.launch { controller.startOn(this@TunnelService, alwaysOn) }
        return START_NOT_STICKY
    }

    override fun onRevoke() {
        scope.launch { controller.onRevoked() }
    }

    /** Called by sing-box, which keeps its own copy of the descriptor. */
    fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) {
            throw IOException("the app has no VPN permission")
        }
        val opened =
            Builder()
                .setSession(getString(R.string.tunnel_channel_name))
                .configure(options, packageName)
                .establish() ?: throw IOException("the system refused the VPN")
        // The old TUN closes last, so a restart never drops the VPN.
        val previous = tun
        tun = opened
        previous?.close()
        return opened.fd
    }

    fun finish() {
        tun?.close()
        tun = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    fun show(notice: TunnelNotice) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(notice))
    }

    private fun goForeground() {
        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification(TunnelNotice.CONNECTING), type)
    }

    private fun notification(notice: TunnelNotice): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.tunnel_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val disconnect =
            PendingIntent.getService(
                this,
                0,
                Intent(this, TunnelService::class.java).setAction(ACTION_DISCONNECT),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        return NotificationCompat
            .Builder(this, CHANNEL_ID)
            .setContentTitle(getString(titleOf(notice)))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(0, getString(R.string.tunnel_disconnect), disconnect)
            .build()
    }

    private fun titleOf(notice: TunnelNotice): Int =
        when (notice) {
            TunnelNotice.CONNECTING -> R.string.tunnel_status_connecting
            TunnelNotice.CONNECTED -> R.string.tunnel_status_connected
            TunnelNotice.DISCONNECTING -> R.string.tunnel_status_disconnecting
        }

    private companion object {
        const val ACTION_DISCONNECT = "com.vpnclient.app.action.DISCONNECT"
        const val CHANNEL_ID = "tunnel"
        const val NOTIFICATION_ID = 1
    }
}
