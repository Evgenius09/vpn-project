package com.vpnclient.app.tunnel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NetChangesTest {
    @Test
    fun eachTransportMapsToItsNetType() {
        assertEquals(NetType.WIFI, netTypeOf(Transports(wifi = true)))
        assertEquals(NetType.CELLULAR, netTypeOf(Transports(cellular = true)))
        assertEquals(NetType.ETHERNET, netTypeOf(Transports(ethernet = true)))
    }

    @Test
    fun noNetworkIsNone() {
        assertEquals(NetType.NONE, netTypeOf(null))
    }

    @Test
    fun anyOtherTransportIsOther() {
        assertEquals(NetType.OTHER, netTypeOf(Transports()))
    }

    @Test
    fun theVpnTransportIsIgnored() {
        assertEquals(NetType.CELLULAR, netTypeOf(Transports(cellular = true, vpn = true)))
        assertEquals(NetType.WIFI, netTypeOf(Transports(wifi = true, vpn = true)))
    }

    @Test
    fun aVpnWithoutAnUnderlyingTransportSaysNothing() {
        assertNull(netTypeOf(Transports(vpn = true)))
    }

    @Test
    fun theWireNamesMatchTheCoreNetType() {
        assertEquals(
            listOf("wifi", "cellular", "ethernet", "other", "none"),
            NetType.entries.map { it.wire },
        )
    }

    private val scheduler = FakeScheduler()
    private val reported = mutableListOf<NetType>()
    private val changes = NetChanges(scheduler) { reported += it }

    @Test
    fun startReportsTheCurrentNetworkAtOnce() {
        changes.start(NetType.WIFI)
        assertEquals(listOf(NetType.WIFI), reported)
    }

    @Test
    fun startWithoutAKnownNetworkReportsNothing() {
        changes.start(null)
        scheduler.advance(DEBOUNCE)
        assertEquals(emptyList<NetType>(), reported)
    }

    @Test
    fun aChangeWaitsForOneSecond() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.CELLULAR)
        scheduler.advance(DEBOUNCE - 1)
        assertEquals(listOf(NetType.WIFI), reported)
        scheduler.advance(1)
        assertEquals(listOf(NetType.WIFI, NetType.CELLULAR), reported)
    }

    @Test
    fun aBurstCollapsesToTheLastValue() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.NONE)
        scheduler.advance(500)
        changes.onChange(NetType.ETHERNET)
        scheduler.advance(900)
        changes.onChange(NetType.CELLULAR)
        scheduler.advance(DEBOUNCE - 1)
        assertEquals(listOf(NetType.WIFI), reported)
        scheduler.advance(1)
        assertEquals(listOf(NetType.WIFI, NetType.CELLULAR), reported)
        scheduler.advance(10 * DEBOUNCE)
        assertEquals(listOf(NetType.WIFI, NetType.CELLULAR), reported)
    }

    @Test
    fun theLastReportedValueIsNotReportedAgain() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.WIFI)
        scheduler.advance(DEBOUNCE)
        changes.onChange(NetType.CELLULAR)
        scheduler.advance(300)
        changes.onChange(NetType.WIFI)
        scheduler.advance(DEBOUNCE)
        assertEquals(listOf(NetType.WIFI), reported)
    }

    @Test
    fun noneIsPassedThrough() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.NONE)
        scheduler.advance(DEBOUNCE)
        assertEquals(listOf(NetType.WIFI, NetType.NONE), reported)
    }

    @Test
    fun stopDropsThePendingChangeAndLaterOnes() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.CELLULAR)
        changes.stop()
        changes.onChange(NetType.ETHERNET)
        scheduler.advance(10 * DEBOUNCE)
        assertEquals(listOf(NetType.WIFI), reported)
    }

    @Test
    fun aChangeBeforeStartIsIgnored() {
        changes.onChange(NetType.CELLULAR)
        scheduler.advance(DEBOUNCE)
        assertEquals(emptyList<NetType>(), reported)
    }

    @Test
    fun aRestartReportsTheNetworkAgain() {
        // The core forgets the network on every start (tech.md 19.10).
        changes.start(NetType.CELLULAR)
        changes.stop()
        changes.start(NetType.CELLULAR)
        assertEquals(listOf(NetType.CELLULAR, NetType.CELLULAR), reported)
    }

    @Test
    fun aRestartForgetsTheLastReport() {
        changes.start(NetType.CELLULAR)
        changes.stop()
        changes.start(null)
        changes.onChange(NetType.CELLULAR)
        scheduler.advance(DEBOUNCE)
        assertEquals(listOf(NetType.CELLULAR, NetType.CELLULAR), reported)
    }

    @Test
    fun aRestartDropsTheChangePendingBeforeIt() {
        changes.start(NetType.WIFI)
        changes.onChange(NetType.CELLULAR)
        changes.start(NetType.ETHERNET)
        scheduler.advance(10 * DEBOUNCE)
        assertEquals(listOf(NetType.WIFI, NetType.ETHERNET), reported)
    }

    private companion object {
        const val DEBOUNCE = 1_000L
    }
}

/** Runs tasks when the test moves its clock past their time. */
private class FakeScheduler : Scheduler {
    private var now = 0L
    private val tasks = mutableListOf<Pair<Long, () -> Unit>>()

    override fun schedule(
        delayMillis: Long,
        task: () -> Unit,
    ): () -> Unit {
        val entry = (now + delayMillis) to task
        tasks += entry
        return { tasks.remove(entry) }
    }

    fun advance(millis: Long) {
        val until = now + millis
        while (true) {
            val next = tasks.filter { it.first <= until }.minByOrNull { it.first } ?: break
            tasks.remove(next)
            now = next.first
            next.second()
        }
        now = until
    }
}
