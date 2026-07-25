import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var bleChannelHandler: BleChannelHandler?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register native BLE platform channel handler
        if let controller = window?.rootViewController as? FlutterViewController {
            bleChannelHandler = BleChannelHandler(messenger: controller.binaryMessenger)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        bleChannelHandler?.dispose()
    }
}
