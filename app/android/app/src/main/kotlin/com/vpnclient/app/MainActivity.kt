package com.vpnclient.app

import android.content.Intent
import android.net.VpnService
import com.vpnclient.app.gen.EventsStreamHandler
import com.vpnclient.app.gen.PigeonEventSink
import com.vpnclient.app.gen.PrepareResult
import com.vpnclient.app.gen.VpnHostApi
import com.vpnclient.app.tunnel.HostApi
import com.vpnclient.app.tunnel.TunnelController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CompletableDeferred

class MainActivity : FlutterActivity() {
    private var permissionResult: CompletableDeferred<PrepareResult>? = null

    private val controller: TunnelController
        get() = TunnelController.get(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VpnHostApi.setUp(messenger, HostApi(controller, ::requestPermission))
        EventsStreamHandler.register(
            messenger,
            object : EventsStreamHandler() {
                override fun onListen(
                    p0: Any?,
                    sink: PigeonEventSink<String>,
                ) {
                    controller.listener = { event -> sink.success(event) }
                }

                override fun onCancel(p0: Any?) {
                    controller.listener = null
                }
            },
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        VpnHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        controller.listener = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private suspend fun requestPermission(): PrepareResult {
        val intent = VpnService.prepare(this) ?: return PrepareResult.GRANTED
        val result = CompletableDeferred<PrepareResult>()
        permissionResult = result
        startActivityForResult(intent, REQUEST_VPN_PERMISSION)
        return result.await()
    }

    @Deprecated("FlutterActivity offers no result API")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION) {
            val granted = resultCode == RESULT_OK
            permissionResult?.complete(if (granted) PrepareResult.GRANTED else PrepareResult.DENIED)
            permissionResult = null
        }
    }

    private companion object {
        const val REQUEST_VPN_PERMISSION = 1
    }
}
