package com.vpnclient.app.tunnel

import android.content.pm.PackageManager
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import com.vpnclient.core.libbox.RoutePrefix
import com.vpnclient.core.libbox.RoutePrefixIterator
import com.vpnclient.core.libbox.StringIterator
import com.vpnclient.core.libbox.TunOptions
import java.net.InetAddress

private const val ALL_IPV4 = "0.0.0.0"
private const val ALL_IPV6 = "::"

private fun RoutePrefixIterator.toList(): List<RoutePrefix> =
    buildList {
        while (hasNext()) {
            add(next())
        }
    }

private fun StringIterator.toList(): List<String> =
    buildList {
        while (hasNext()) {
            add(next())
        }
    }

private fun RoutePrefix.toIpPrefix(): IpPrefix = IpPrefix(InetAddress.getByName(address()), prefix())

/** Applies what sing-box computed for the TUN. The order follows the official client. */
internal fun VpnService.Builder.configure(
    options: TunOptions,
    ownPackage: String,
): VpnService.Builder {
    setMtu(options.mtu)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        setMetered(false)
    }
    val inet4 = options.inet4Address.toList()
    val inet6 = options.inet6Address.toList()
    (inet4 + inet6).forEach { addAddress(it.address(), it.prefix()) }

    if (options.autoRoute) {
        options.dnsServerAddress.toList().forEach { addDnsServer(it) }
        addRoutes(options, hasInet4 = inet4.isNotEmpty(), hasInet6 = inet6.isNotEmpty())
    }
    applyPackages(packageRules(options.includePackage.toList(), options.excludePackage.toList()), ownPackage)
    return this
}

private fun VpnService.Builder.addRoutes(
    options: TunOptions,
    hasInet4: Boolean,
    hasInet6: Boolean,
) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        // Before API 33 a route cannot be excluded, so sing-box computes ranges.
        (options.inet4RouteRange.toList() + options.inet6RouteRange.toList())
            .forEach { addRoute(it.address(), it.prefix()) }
        return
    }
    val routes4 = options.inet4RouteAddress.toList()
    val routes6 = options.inet6RouteAddress.toList()
    (routes4 + routes6).forEach { addRoute(it.toIpPrefix()) }
    if (routes4.isEmpty() && hasInet4) addRoute(ALL_IPV4, 0)
    if (routes6.isEmpty() && hasInet6) addRoute(ALL_IPV6, 0)
    (options.inet4RouteExcludeAddress.toList() + options.inet6RouteExcludeAddress.toList())
        .forEach { excludeRoute(it.toIpPrefix()) }
}

/**
 * A package the user removed must not take the tunnel down. If none of the
 * included apps is left, the builder would route every app, so the app itself
 * has to be excluded by hand.
 */
private fun VpnService.Builder.applyPackages(
    rules: PackageRules,
    ownPackage: String,
) {
    val allowed = rules.allowed.count { installed { addAllowedApplication(it) } }
    rules.disallowed.forEach { installed { addDisallowedApplication(it) } }
    if (rules.allowed.isNotEmpty() && allowed == 0) {
        addDisallowedApplication(ownPackage)
    }
}

private fun installed(apply: () -> Unit): Boolean =
    try {
        apply()
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
