package com.bitmsg.bitmsg

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel handler bridging Dart ↔ native BLE peripheral operations.
 *
 * Methods (Dart → Kotlin):
 *   - startAdvertising
 *   - stopAdvertising
 *   - sendData { peerId, data }
 *   - broadcastData { data }
 *   - getMtu { peerId } → Int
 *   - startForegroundService
 *   - stopForegroundService
 *
 * Events (Kotlin → Dart):
 *   - dataReceived { peerId, data }
 *   - peerConnected { peerId }
 *   - peerDisconnected { peerId }
 */
class BleMethodChannelHandler(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "BleMethodChannelHandler"
    }

    private val methodChannel = MethodChannel(messenger, "com.bitmsg/ble_peripheral")
    private val eventChannel = EventChannel(messenger, "com.bitmsg/ble_peripheral_events")
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var gattServer: BleGattServer? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAdvertising" -> {
                try {
                    val success = startGattServer()
                    if (success) {
                        result.success(null)
                    } else {
                        result.error("BLE_ERROR", "Failed to start GATT server (Bluetooth may be off or unsupported)", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "startAdvertising error: ${e.message}")
                    result.error("BLE_ERROR", e.message, null)
                }
            }

            "stopAdvertising" -> {
                gattServer?.stop()
                gattServer = null
                result.success(null)
            }

            "sendData" -> {
                val peerId = call.argument<String>("peerId")
                val data = call.argument<ByteArray>("data")
                if (peerId != null && data != null) {
                    val success = gattServer?.sendData(peerId, data) ?: false
                    result.success(success)
                } else {
                    result.error("INVALID_ARGS", "peerId and data are required", null)
                }
            }

            "broadcastData" -> {
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    gattServer?.broadcastData(data)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "data is required", null)
                }
            }

            "getMtu" -> {
                val peerId = call.argument<String>("peerId")
                if (peerId != null) {
                    val mtu = gattServer?.getMtu(peerId) ?: 23
                    result.success(mtu)
                } else {
                    result.error("INVALID_ARGS", "peerId is required", null)
                }
            }

            "startForegroundService" -> {
                val intent = Intent(context, BleForegroundService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(null)
            }

            "stopForegroundService" -> {
                val intent = Intent(context, BleForegroundService::class.java)
                context.stopService(intent)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Starts the GATT server if not already running.
     * Returns true on success, false on failure.
     */
    private fun startGattServer(): Boolean {
        if (gattServer != null) return true // Already running

        val server = BleGattServer(context).apply {
            onDataReceived = { peerId, data ->
                sendEvent(mapOf("type" to "dataReceived", "peerId" to peerId, "data" to data))
            }
            onPeerConnected = { peerId ->
                sendEvent(mapOf("type" to "peerConnected", "peerId" to peerId))
            }
            onPeerDisconnected = { peerId ->
                sendEvent(mapOf("type" to "peerDisconnected", "peerId" to peerId))
            }
        }

        val started = server.start()
        if (started) {
            gattServer = server
            Log.d(TAG, "GATT server started successfully")
        } else {
            Log.e(TAG, "GATT server failed to start — cleaning up partial state")
            server.stop()
        }
        return started
    }

    private fun sendEvent(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        gattServer?.stop()
        gattServer = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
