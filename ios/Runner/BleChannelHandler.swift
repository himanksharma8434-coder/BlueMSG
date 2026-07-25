import Flutter
import Foundation

/// Platform channel handler bridging Dart ↔ native iOS CoreBluetooth BLE operations.
///
/// Methods (Dart → Swift via MethodChannel):
///   - startAdvertising
///   - stopAdvertising
///   - startScanning
///   - stopScanning
///   - sendData { peerId, data }
///   - stop
///
/// Events (Swift → Dart via EventChannel):
///   - dataReceived { peerId, data }
///   - peerConnected { peerId }
///   - peerDisconnected { peerId }
///   - peerDiscovered { peerId, name, rssi }
class BleChannelHandler: NSObject, FlutterStreamHandler {
    
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private let bleManager = BleCoreBluetoothManager()
    
    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.bitmsg/ble_peripheral",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.bitmsg/ble_peripheral_events",
            binaryMessenger: messenger
        )
        
        super.init()
        
        methodChannel.setMethodCallHandler(handleMethodCall)
        eventChannel.setStreamHandler(self)
        
        setupBleCallbacks()
        bleManager.initialize()
    }
    
    // MARK: - BLE Callbacks → Dart Events
    
    private func setupBleCallbacks() {
        bleManager.onDataReceived = { [weak self] peerId, data in
            self?.sendEvent([
                "type": "dataReceived",
                "peerId": peerId,
                "data": FlutterStandardTypedData(bytes: data)
            ])
        }
        
        bleManager.onPeerConnected = { [weak self] peerId in
            self?.sendEvent([
                "type": "peerConnected",
                "peerId": peerId
            ])
        }
        
        bleManager.onPeerDisconnected = { [weak self] peerId in
            self?.sendEvent([
                "type": "peerDisconnected",
                "peerId": peerId
            ])
        }
        
        bleManager.onPeerDiscovered = { [weak self] peerId, name, rssi in
            var event: [String: Any] = [
                "type": "peerDiscovered",
                "peerId": peerId,
                "rssi": rssi
            ]
            if let name = name {
                event["name"] = name
            }
            self?.sendEvent(event)
        }
    }
    
    // MARK: - MethodChannel Handler
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            bleManager.startAdvertising()
            result(nil)
            
        case "stopAdvertising":
            bleManager.stopAdvertising()
            result(nil)
            
        case "startScanning":
            bleManager.startScanning()
            result(nil)
            
        case "stopScanning":
            bleManager.stopScanning()
            result(nil)
            
        case "sendData":
            guard let args = call.arguments as? [String: Any],
                  let peerId = args["peerId"] as? String,
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "peerId and data required", details: nil))
                return
            }
            
            // Try peripheral mode first (send to connected central)
            let sentViaCentral = bleManager.sendToConnectedCentral(peerId: peerId, data: data.data)
            if !sentViaCentral {
                // Fallback: write to peripheral's write characteristic
                bleManager.sendToPeripheral(peerId: peerId, data: data.data)
            }
            result(true)
            
        case "stop":
            bleManager.stop()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - EventChannel StreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - Helpers
    
    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
    
    func dispose() {
        bleManager.stop()
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}
