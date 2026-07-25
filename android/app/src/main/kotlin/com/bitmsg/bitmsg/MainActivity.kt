package com.bitmsg.bitmsg

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bleHandler: BleMethodChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bleHandler = BleMethodChannelHandler(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bleHandler?.dispose()
        bleHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
