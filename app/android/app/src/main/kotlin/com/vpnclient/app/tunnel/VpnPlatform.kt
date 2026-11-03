package com.vpnclient.app.tunnel

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.system.OsConstants
import com.vpnclient.core.libbox.BridgeOptions
import com.vpnclient.core.libbox.BridgeSession
import com.vpnclient.core.libbox.ConnectionOwner
import com.vpnclient.core.libbox.InterfaceUpdateListener
import com.vpnclient.core.libbox.Libbox
import com.vpnclient.core.libbox.LocalDNSTransport
import com.vpnclient.core.libbox.NeighborUpdateListener
import com.vpnclient.core.libbox.NetworkInterface
import com.vpnclient.core.libbox.NetworkInterfaceIterator
import com.vpnclient.core.libbox.Notification
import com.vpnclient.core.libbox.PlatformInterface
import com.vpnclient.core.libbox.PlatformUser
import com.vpnclient.core.libbox.ShellSession
import com.vpnclient.core.libbox.StringIterator
import com.vpnclient.core.libbox.TunOptions
import com.vpnclient.core.libbox.WIFIState
import java.io.IOException
import java.net.NetworkInterface as JavaNetworkInterface

private const val NOT_IN_CLIENT = "not used by this client"

/**
 * The host side of sing-box. Most of the interface serves features this client
 * does not ship, so those members refuse.
 */
class VpnPlatform(context: Context) : PlatformInterface {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val callbacks = HashMap<InterfaceUpdateListener, ConnectivityManager.NetworkCallback>()

    @Volatile
    var service: TunnelService? = null

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        val vpn: VpnService = service ?: throw IOException("tunnel service is not running")
        if (!vpn.protect(fd)) {
            throw IOException("protect socket failed")
        }
    }

    override fun openTun(options: TunOptions): Int {
        val vpn = service ?: throw IOException("tunnel service is not running")
        return vpn.openTun(options)
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val callback = DefaultNetworkCallback(listener)
        synchronized(callbacks) { callbacks[listener] = callback }
        connectivity.watchPhysicalNetwork(callback, handler)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val callback = synchronized(callbacks) { callbacks.remove(listener) } ?: return
        connectivity.unregisterNetworkCallback(callback)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val interfaces =
            connectivity.allNetworks.mapNotNull { network ->
                connectivity.getLinkProperties(network)?.let { describe(network, it) }
            }
        return NetworkInterfaces(interfaces.iterator())
    }

    private fun describe(
        network: Network,
        properties: LinkProperties,
    ): NetworkInterface? {
        val name = properties.interfaceName ?: return null
        val system = JavaNetworkInterface.getByName(name) ?: return null
        val capabilities = connectivity.getNetworkCapabilities(network)
        return NetworkInterface().apply {
            setName(name)
            index = system.index
            mtu = system.mtu
            addresses = Strings(properties.linkAddresses.map { it.toString() })
            flags = flagsOf(system)
            type = typeOf(capabilities)
            metered = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) != true
            dnsServer = Strings(properties.dnsServers.mapNotNull { it.hostAddress })
            gateway =
                Strings(
                    properties.routes
                        .filter { it.isDefaultRoute }
                        .mapNotNull { it.gateway?.hostAddress },
                )
        }
    }

    private fun flagsOf(system: JavaNetworkInterface): Int {
        var flags = 0
        if (system.isUp) flags = flags or OsConstants.IFF_UP or OsConstants.IFF_RUNNING
        if (system.isLoopback) flags = flags or OsConstants.IFF_LOOPBACK
        if (system.isPointToPoint) flags = flags or OsConstants.IFF_POINTOPOINT
        if (system.supportsMulticast()) flags = flags or OsConstants.IFF_MULTICAST
        return flags
    }

    private fun typeOf(capabilities: NetworkCapabilities?): Int =
        when {
            capabilities == null -> Libbox.InterfaceTypeOther
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
            else -> Libbox.InterfaceTypeOther
        }

    private inner class DefaultNetworkCallback(
        private val listener: InterfaceUpdateListener,
    ) : ConnectivityManager.NetworkCallback() {
        private var capabilities: NetworkCapabilities? = null
        private var current: Network? = null

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            capabilities = networkCapabilities
        }

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties,
        ) {
            val name = linkProperties.interfaceName ?: return
            val index = JavaNetworkInterface.getByName(name)?.index ?: return
            val expensive = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) != true
            current = network
            listener.updateDefaultInterface(name, index, expensive, false)
        }

        override fun onLost(network: Network) {
            // The previous network is lost after the next one arrives, and must not hide it.
            if (network != current) return
            current = null
            listener.updateDefaultInterface("", -1, false, false)
        }
    }

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() = Unit

    override fun registerMyInterface(name: String) = Unit

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner = throw IOException(NOT_IN_CLIENT)

    override fun sendNotification(notification: Notification) = Unit

    override fun cancelNotification(
        identifier: String,
        typeID: Int,
    ) = Unit

    override fun startNeighborMonitor(listener: NeighborUpdateListener) = Unit

    override fun closeNeighborMonitor(listener: NeighborUpdateListener) = Unit

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() = throw IOException(NOT_IN_CLIENT)

    override fun openShellSession(
        user: PlatformUser,
        command: String,
        environ: StringIterator,
        term: String,
        rows: Int,
        cols: Int,
    ): ShellSession = throw IOException(NOT_IN_CLIENT)

    override fun lookupUser(username: String): PlatformUser = throw IOException(NOT_IN_CLIENT)

    override fun lookupSFTPServer(): String = throw IOException(NOT_IN_CLIENT)

    override fun readSystemSSHHostKey(): String = throw IOException(NOT_IN_CLIENT)

    override fun tailscaleHostname(): String = ""

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(options: BridgeOptions): BridgeSession = throw IOException(NOT_IN_CLIENT)
}

private class NetworkInterfaces(
    private val items: Iterator<NetworkInterface>,
) : NetworkInterfaceIterator {
    override fun hasNext(): Boolean = items.hasNext()

    override fun next(): NetworkInterface = items.next()
}

private class Strings(
    private val values: List<String>,
) : StringIterator {
    private val items = values.iterator()

    override fun hasNext(): Boolean = items.hasNext()

    override fun len(): Int = values.size

    override fun next(): String = items.next()
}
