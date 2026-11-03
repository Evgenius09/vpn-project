package com.vpnclient.app.tunnel

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.HandlerThread

/**
 * Reports the NetType of the default network while the tunnel runs. The
 * tunnel service owns it, so reports keep coming with the UI in the background
 * or killed. The app is outside its own VPN, so its default network is the
 * physical one.
 *
 * Everything runs on one thread, which [NetChanges] requires, and the core
 * call blocks only that thread.
 */
class NetworkMonitor(
    context: Context,
    report: (String) -> Unit,
) {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val thread = HandlerThread("network-monitor").apply { start() }
    private val handler = Handler(thread.looper)
    private val changes = NetChanges(HandlerScheduler(handler)) { report(it.wire) }
    private var callback: DefaultNetworkCallback? = null

    /** Reports the current network at once, then every settled change. */
    fun start() {
        handler.post {
            unregister()
            changes.start(current())
            val next = DefaultNetworkCallback()
            callback = next
            // The variant without a Handler exists from API 24, the minimum SDK.
            connectivity.registerDefaultNetworkCallback(next)
        }
    }

    fun stop() {
        handler.post {
            unregister()
            changes.stop()
        }
    }

    /** Ends the thread. The monitor is unusable afterwards. */
    fun close() {
        stop()
        thread.quitSafely()
    }

    private fun current(): NetType? {
        val network = connectivity.activeNetwork ?: return NetType.NONE
        return netTypeOf(connectivity.getNetworkCapabilities(network)?.let(::transportsOf))
    }

    private fun unregister() {
        val registered = callback ?: return
        callback = null
        connectivity.unregisterNetworkCallback(registered)
    }

    private inner class DefaultNetworkCallback : ConnectivityManager.NetworkCallback() {
        private var network: Network? = null

        override fun onAvailable(network: Network) {
            // Before API 26 no capabilities callback follows onAvailable.
            val capabilities = connectivity.getNetworkCapabilities(network) ?: return
            onCapabilitiesChanged(network, capabilities)
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            val type = netTypeOf(transportsOf(networkCapabilities)) ?: return
            onThread {
                this.network = network
                changes.onChange(type)
            }
        }

        override fun onLost(network: Network) {
            onThread {
                // A late loss of the previous default must not hide the new one.
                if (network == this.network) {
                    this.network = null
                    changes.onChange(NetType.NONE)
                }
            }
        }

        /** Drops callbacks that arrive after this callback was unregistered. */
        private fun onThread(block: () -> Unit) {
            handler.post {
                if (callback === this) {
                    block()
                }
            }
        }
    }
}

private fun transportsOf(capabilities: NetworkCapabilities) =
    Transports(
        wifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
        cellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
        ethernet = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET),
        vpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN),
    )

private class HandlerScheduler(
    private val handler: Handler,
) : Scheduler {
    override fun schedule(
        delayMillis: Long,
        task: () -> Unit,
    ): () -> Unit {
        val runnable = Runnable { task() }
        handler.postDelayed(runnable, delayMillis)
        return { handler.removeCallbacks(runnable) }
    }
}
