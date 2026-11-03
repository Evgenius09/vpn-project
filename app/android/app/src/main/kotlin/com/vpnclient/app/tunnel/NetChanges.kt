package com.vpnclient.app.tunnel

/** The NetType of tech.md 5.7, with the names the core reads. */
enum class NetType(val wire: String) {
    WIFI("wifi"),
    CELLULAR("cellular"),
    ETHERNET("ethernet"),
    OTHER("other"),
    NONE("none"),
}

/** The transports of a network, read from NetworkCapabilities at the edge. */
data class Transports(
    val wifi: Boolean = false,
    val cellular: Boolean = false,
    val ethernet: Boolean = false,
    val vpn: Boolean = false,
)

/**
 * Maps the transports of the active network, or null for no network. A VPN
 * carries the transports of the network under it, so its own flag is ignored.
 * A VPN without them says nothing about the link and yields null, so the last
 * report stands.
 */
fun netTypeOf(transports: Transports?): NetType? =
    when {
        transports == null -> NetType.NONE
        transports.wifi -> NetType.WIFI
        transports.cellular -> NetType.CELLULAR
        transports.ethernet -> NetType.ETHERNET
        transports.vpn -> null
        else -> NetType.OTHER
    }

/** Runs a task later and returns a call that cancels it. */
fun interface Scheduler {
    fun schedule(
        delayMillis: Long,
        task: () -> Unit,
    ): () -> Unit
}

/**
 * Turns network callbacks into NetChanged reports for the core. A switch from
 * Wi-Fi to cellular arrives as a burst of callbacks, so a change is reported
 * only after it held for the debounce time, and only when it differs from the
 * last report. Not thread-safe: the caller confines it to one thread.
 */
class NetChanges(
    private val scheduler: Scheduler,
    private val delayMillis: Long = DEBOUNCE_MILLIS,
    private val report: (NetType) -> Unit,
) {
    private var running = false
    private var last: NetType? = null
    private var pending: NetType? = null
    private var cancelPending: (() -> Unit)? = null

    /**
     * Reports the current network at once, because the core forgets the
     * network on every start (tech.md 19.10).
     */
    fun start(current: NetType?) {
        stop()
        running = true
        if (current != null) {
            emit(current)
        }
    }

    fun onChange(type: NetType) {
        if (!running) {
            return
        }
        pending = type
        cancelPending?.invoke()
        cancelPending = scheduler.schedule(delayMillis, ::settle)
    }

    fun stop() {
        cancelPending?.invoke()
        cancelPending = null
        pending = null
        last = null
        running = false
    }

    private fun settle() {
        cancelPending = null
        val type = pending ?: return
        pending = null
        if (type != last) {
            emit(type)
        }
    }

    private fun emit(type: NetType) {
        last = type
        report(type)
    }

    companion object {
        const val DEBOUNCE_MILLIS = 1_000L
    }
}
