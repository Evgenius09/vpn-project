package com.vpnclient.app.tunnel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LastRequestTest {
    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun nothingIsStoredAtFirst() {
        assertNull(LastRequest(folder.root).read())
    }

    @Test
    fun theLastWriteWins() {
        val stored = LastRequest(folder.root)
        stored.write("first")
        stored.write("second")
        assertEquals("second", LastRequest(folder.root).read())
    }

    @Test
    fun aWriteLeavesNoTemporaryFile() {
        LastRequest(folder.root).write("request")
        assertEquals(listOf("last_request.json"), folder.root.list()!!.toList())
    }
}
