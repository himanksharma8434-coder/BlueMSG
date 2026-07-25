import CoreBluetooth
import Foundation

/// Native CoreBluetooth BLE manager for iOS.
///
/// Uses raw CBPeripheralManager (peripheral/advertiser) and CBCentralManager (central/scanner)
/// for protocol-level compatibility with the Android BLE implementation.
///
/// ## iOS Background Limitations (documented):
/// - When backgrounded, advertising only broadcasts a reduced payload (overflow area,
///   no full service UUID visible to non-iOS devices scanning in foreground).
/// - Background scanning requires pre-declared service UUIDs in `scanForPeripherals`.
/// - State restoration via `CBCentralManagerOptionRestoreIdentifierKey` helps recover
///   connections after app suspension, but is not guaranteed.
/// - **Recommendation**: Show a UI banner telling users mesh relay works best with the app open.
class BleCoreBluetoothManager: NSObject {
    
    // MARK: - Constants
    
    static let serviceUUID = CBUUID(string: "B1TM5G00-4D65-7368-4E65-74776F726B00")
    static let writeCharUUID = CBUUID(string: "B1TM5G01-4D65-7368-4E65-74776F726B00")
    static let notifyCharUUID = CBUUID(string: "B1TM5G02-4D65-7368-4E65-74776F726B00")
    static let centralRestoreId = "com.bitmsg.central"
    static let peripheralRestoreId = "com.bitmsg.peripheral"
    
    // MARK: - Managers
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    
    // MARK: - State
    
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedCentrals: [String: CBCentral] = [:]
    private var notifyCharacteristic: CBMutableCharacteristic?
    private var isAdvertising = false
    private var isScanning = false
    
    // MARK: - Callbacks to Dart
    
    var onDataReceived: ((_ peerId: String, _ data: Data) -> Void)?
    var onPeerConnected: ((_ peerId: String) -> Void)?
    var onPeerDisconnected: ((_ peerId: String) -> Void)?
    var onPeerDiscovered: ((_ peerId: String, _ name: String?, _ rssi: Int) -> Void)?
    
    // MARK: - Initialization
    
    func initialize() {
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.bitmsg.ble.central"),
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BleCoreBluetoothManager.centralRestoreId,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
        
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.bitmsg.ble.peripheral"),
            options: [
                CBPeripheralManagerOptionRestoreIdentifierKey: BleCoreBluetoothManager.peripheralRestoreId
            ]
        )
    }
    
    // MARK: - Advertising (Peripheral Mode)
    
    func startAdvertising() {
        guard let pm = peripheralManager, pm.state == .poweredOn else {
            NSLog("[bitmsg] Cannot start advertising: peripheral manager not ready")
            return
        }
        
        guard !isAdvertising else { return }
        
        // Build GATT service
        let writeChar = CBMutableCharacteristic(
            type: BleCoreBluetoothManager.writeCharUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        let notifyChar = CBMutableCharacteristic(
            type: BleCoreBluetoothManager.notifyCharUUID,
            properties: [.notify, .read],
            value: nil,
            permissions: [.readable]
        )
        self.notifyCharacteristic = notifyChar
        
        let service = CBMutableService(type: BleCoreBluetoothManager.serviceUUID, primary: true)
        service.characteristics = [writeChar, notifyChar]
        
        pm.add(service)
        
        pm.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BleCoreBluetoothManager.serviceUUID],
            CBAdvertisementDataLocalNameKey: "bitmsg"
        ])
        
        isAdvertising = true
        NSLog("[bitmsg] BLE advertising started")
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        NSLog("[bitmsg] BLE advertising stopped")
    }
    
    // MARK: - Scanning (Central Mode)
    
    func startScanning() {
        guard let cm = centralManager, cm.state == .poweredOn else {
            NSLog("[bitmsg] Cannot start scanning: central manager not ready")
            return
        }
        
        guard !isScanning else { return }
        
        cm.scanForPeripherals(
            withServices: [BleCoreBluetoothManager.serviceUUID],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )
        
        isScanning = true
        NSLog("[bitmsg] BLE scanning started")
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        NSLog("[bitmsg] BLE scanning stopped")
    }
    
    // MARK: - Send Data
    
    /// Send data to a connected central via notification (peripheral mode).
    func sendToConnectedCentral(peerId: String, data: Data) -> Bool {
        guard let pm = peripheralManager,
              let notifyChar = notifyCharacteristic,
              let central = connectedCentrals[peerId] else {
            return false
        }
        
        return pm.updateValue(data, for: notifyChar, onSubscribedCentrals: [central])
    }
    
    /// Send data to a connected peripheral by writing to its write characteristic (central mode).
    func sendToPeripheral(peerId: String, data: Data) {
        guard let peripheral = discoveredPeripherals[peerId] else {
            NSLog("[bitmsg] Cannot send: peripheral \(peerId) not found")
            return
        }
        
        // Find the write characteristic on the connected peripheral
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == BleCoreBluetoothManager.serviceUUID {
                if let chars = service.characteristics {
                    for char in chars {
                        if char.uuid == BleCoreBluetoothManager.writeCharUUID {
                            peripheral.writeValue(data, for: char, type: .withResponse)
                            return
                        }
                    }
                }
            }
        }
    }
    
    /// Broadcast data to all subscribed centrals.
    func broadcastToCentrals(data: Data) {
        guard let pm = peripheralManager, let notifyChar = notifyCharacteristic else { return }
        pm.updateValue(data, for: notifyChar, onSubscribedCentrals: nil)
    }
    
    // MARK: - Cleanup
    
    func stop() {
        stopScanning()
        stopAdvertising()
        
        for (_, peripheral) in discoveredPeripherals {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        discoveredPeripherals.removeAll()
        connectedCentrals.removeAll()
        
        NSLog("[bitmsg] BLE manager stopped")
    }
}

// MARK: - CBCentralManagerDelegate

extension BleCoreBluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("[bitmsg] Central manager state: \(central.state.rawValue)")
        if central.state == .poweredOn && isScanning {
            // Re-start scanning after Bluetooth turned back on
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let peerId = peripheral.identifier.uuidString
        
        if discoveredPeripherals[peerId] == nil {
            NSLog("[bitmsg] Discovered peer: \(peerId)")
            discoveredPeripherals[peerId] = peripheral
            peripheral.delegate = self
            
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            onPeerDiscovered?(peerId, name, RSSI.intValue)
            
            // Auto-connect
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peerId = peripheral.identifier.uuidString
        NSLog("[bitmsg] Connected to peripheral: \(peerId)")
        onPeerConnected?(peerId)
        
        // Discover our mesh service
        peripheral.discoverServices([BleCoreBluetoothManager.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let peerId = peripheral.identifier.uuidString
        NSLog("[bitmsg] Disconnected from peripheral: \(peerId)")
        discoveredPeripherals.removeValue(forKey: peerId)
        onPeerDisconnected?(peerId)
        
        // Auto-reconnect if still scanning
        if isScanning {
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peerId = peripheral.identifier.uuidString
        NSLog("[bitmsg] Failed to connect to peripheral: \(peerId), error: \(error?.localizedDescription ?? "unknown")")
        discoveredPeripherals.removeValue(forKey: peerId)
    }
    
    // State restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                let peerId = peripheral.identifier.uuidString
                discoveredPeripherals[peerId] = peripheral
                peripheral.delegate = self
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BleCoreBluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == BleCoreBluetoothManager.serviceUUID {
                peripheral.discoverCharacteristics(
                    [BleCoreBluetoothManager.writeCharUUID, BleCoreBluetoothManager.notifyCharUUID],
                    for: service
                )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.uuid == BleCoreBluetoothManager.notifyCharUUID {
                // Subscribe to notifications from this peripheral
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let peerId = peripheral.identifier.uuidString
        onDataReceived?(peerId, data)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BleCoreBluetoothManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        NSLog("[bitmsg] Peripheral manager state: \(peripheral.state.rawValue)")
        if peripheral.state == .poweredOn && !isAdvertising {
            // Auto-start advertising when Bluetooth comes on
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BleCoreBluetoothManager.writeCharUUID,
               let data = request.value {
                let peerId = request.central.identifier.uuidString
                onDataReceived?(peerId, data)
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let peerId = central.identifier.uuidString
        NSLog("[bitmsg] Central subscribed to notifications: \(peerId)")
        connectedCentrals[peerId] = central
        onPeerConnected?(peerId)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let peerId = central.identifier.uuidString
        NSLog("[bitmsg] Central unsubscribed: \(peerId)")
        connectedCentrals.removeValue(forKey: peerId)
        onPeerDisconnected?(peerId)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            NSLog("[bitmsg] Advertising failed: \(error.localizedDescription)")
            isAdvertising = false
        } else {
            NSLog("[bitmsg] Advertising started successfully")
        }
    }
    
    // State restoration
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        NSLog("[bitmsg] Peripheral manager restoring state")
    }
}
