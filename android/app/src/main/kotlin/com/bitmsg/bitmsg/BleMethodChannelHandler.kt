package com.bitmsg.bitmsg

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
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
                    startGattServer()
                    result.success(null)
                } catch (e: Exception) {
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

    private fun startGattServer() {
        if (gattServer != null) return // Already running

        gattServer = BleGattServer(context).apply {
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
        gattServer?.start()
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
