package com.vpnclient.app.tunnel

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler

/**
 * Follows the network the system would pick outside any VPN. The default
 * network callback reports the app's own tun0 once the tunnel is up, even
 * though the app is excluded from it (Android 12), so the request asks for
 * NOT_VPN, as the official sing-box client does.
 *
 * Below API 31 the callbacks arrive on a system thread.
 */
internal fun ConnectivityManager.watchPhysicalNetwork(
    callback: ConnectivityManager.NetworkCallback,
    handler: Handler,
) {
    val request =
        NetworkRequest
            .Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        registerBestMatchingNetworkCallback(request, callback, handler)
    } else {
        // The variant without a Handler exists from API 21, below the minimum SDK.
        requestNetwork(request, callback)
    }
}
