import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../transport_interface.dart';
import 'ble_constants.dart';

/// Android BLE transport implementation.
///
/// - **Central mode** (scanning + GATT client): Uses `flutter_blue_plus`.
/// - **Peripheral mode** (advertising + GATT server): Uses native Kotlin via platform channels
///   because flutter_blue_plus does not support peripheral/GATT server mode.
class AndroidBleTransport implements Transport {
  // Platform channels for native peripheral-mode GATT server
  static const MethodChannel _methodChannel =
      MethodChannel('com.bitmsg/ble_peripheral');
  static const EventChannel _eventChannel =
      EventChannel('com.bitmsg/ble_peripheral_events');

  // State
  bool _isActive = false;
  final Set<String> _connectedPeers = {};
  final Map<String, BluetoothDevice> _fbpDevices = {};

  // Stream controllers
  final StreamController<({String peerId, Uint8List data})> _incomingDataCtrl =
      StreamController.broadcast();
  final StreamController<DiscoveredPeer> _peerDiscoveredCtrl =
      StreamController.broadcast();
  final StreamController<String> _peerLostCtrl =
      StreamController.broadcast();

  // Subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _peripheralEventSubscription;
  final Map<String, StreamSubscription> _notifySubscriptions = {};

  @override
  bool get isActive => _isActive;

  @override
  Set<String> get connectedPeers => Set.unmodifiable(_connectedPeers);

  @override
  Stream<({String peerId, Uint8List data})> get incomingData =>
      _incomingDataCtrl.stream;

  @override
  Stream<DiscoveredPeer> get peerDiscovered => _peerDiscoveredCtrl.stream;

  @override
  Stream<String> get peerLost => _peerLostCtrl.stream;

  // ── Permissions ──────────────────────────────────────────────────────

  /// Request all required BLE permissions for Android 12+ and older versions.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // Required for BLE scan on Android < 12
    ].request();

    return statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );
  }

  // ── Advertising (Peripheral Mode — Native Kotlin) ────────────────────

  @override
  Future<void> startAdvertising() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        return;
      }
      await _methodChannel.invokeMethod('startAdvertising');
      _listenToPeripheralEvents();
    } catch (e) {
      // Gracefully log advertising failure (e.g. Bluetooth turned off or unsupported)
    }
  }

  @override
  Future<void> stopAdvertising() async {
    try {
      await _methodChannel.invokeMethod('stopAdvertising');
    } catch (_) {}
  }

  /// Listen to events from the native GATT server (data received, peer connected/disconnected).
  void _listenToPeripheralEvents() {
    _peripheralEventSubscription?.cancel();
    _peripheralEventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {
      if (event is! Map) return;
      final type = event['type'] as String?;

      switch (type) {
        case 'dataReceived':
          final peerId = event['peerId'] as String? ?? 'unknown';
          final data = event['data'] as Uint8List?;
          if (data != null) {
            _incomingDataCtrl.add((peerId: peerId, data: data));
          }
          break;

        case 'peerConnected':
          final peerId = event['peerId'] as String? ?? 'unknown';
          _connectedPeers.add(peerId);
          _peerDiscoveredCtrl.add(DiscoveredPeer(
            peerId: peerId,
            discoveredAt: DateTime.now(),
          ));
          break;

        case 'peerDisconnected':
          final peerId = event['peerId'] as String? ?? 'unknown';
          _connectedPeers.remove(peerId);
          _peerLostCtrl.add(peerId);
          break;
      }
    }, onError: (_) {});
  }

  // ── Scanning (Central Mode — flutter_blue_plus) ──────────────────────

  @override
  Future<void> startScanning() async {
    _isActive = true;

    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return;

      // Continuous scan with the mesh service UUID filter
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            _handleScanResult(result);
          }
        },
        onError: (_) {},
      );

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        androidUsesFineLocation: true,
        continuousUpdates: true,
        continuousDivisor: 1,
      );
    } catch (_) {
      // Gracefully handle scan start errors (e.g., Bluetooth turned off)
    }
  }

  @override
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void _handleScanResult(ScanResult result) {
    final device = result.device;
    final peerId = device.remoteId.str;

    if (!_connectedPeers.contains(peerId)) {
      _connectedPeers.add(peerId);
      _fbpDevices[peerId] = device;
      _peerDiscoveredCtrl.add(DiscoveredPeer(
        peerId: peerId,
        name: device.platformName.isNotEmpty ? device.platformName : null,
        rssi: result.rssi,
        discoveredAt: DateTime.now(),
      ));

      // Auto-connect and discover services
      _connectAndDiscover(device, peerId);
    }
  }

  /// Connect to a discovered peer, discover the mesh service, subscribe to notifications.
  Future<void> _connectAndDiscover(BluetoothDevice device, String peerId) async {
    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedPeers.remove(peerId);
          _fbpDevices.remove(peerId);
          _notifySubscriptions[peerId]?.cancel();
          _notifySubscriptions.remove(peerId);
          _peerLostCtrl.add(peerId);
        }
      });

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.str.toLowerCase();

            // Subscribe to the notify characteristic for incoming data
            if (charUuid == BleConstants.notifyCharUuid.toLowerCase()) {
              await char.setNotifyValue(true);
              _notifySubscriptions[peerId]?.cancel();
              _notifySubscriptions[peerId] = char.onValueReceived.listen((value) {
                _incomingDataCtrl.add((
                  peerId: peerId,
                  data: Uint8List.fromList(value),
                ));
              });
            }
          }
          break; // Found our service, done
        }
      }
    } catch (e) {
      // Connection failed — remove peer
      _connectedPeers.remove(peerId);
      _fbpDevices.remove(peerId);
    }
  }

  // ── Sending Data ─────────────────────────────────────────────────────

  @override
  Future<void> send(String peerId, Uint8List data) async {
    // Try central-mode write first (we're the GATT client writing to the peer's GATT server)
    final device = _fbpDevices[peerId];
    if (device != null) {
      await _writeViaCentral(device, data);
      return;
    }

    // Fallback: try sending via the native peripheral-side (peer connected to our GATT server)
    await _writeViaPeripheral(peerId, data);
  }

  @override
  Future<void> broadcast(Uint8List data) async {
    // Send to all connected peers
    final peers = List<String>.from(_connectedPeers);
    for (final peerId in peers) {
      try {
        await send(peerId, data);
      } catch (_) {
        // Best-effort broadcast — skip failed peers
      }
    }
  }

  /// Write data to a peer's GATT server writable characteristic (central mode).
  Future<void> _writeViaCentral(BluetoothDevice device, Uint8List data) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.str.toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          if (char.uuid.str.toLowerCase() == BleConstants.writeCharUuid.toLowerCase()) {
            await char.write(data, withoutResponse: false);
            return;
          }
        }
      }
    }
    throw Exception('Mesh write characteristic not found on peer ${device.remoteId.str}');
  }

  /// Write data via native peripheral channel (GATT server notifying a connected central).
  Future<void> _writeViaPeripheral(String peerId, Uint8List data) async {
    try {
      await _methodChannel.invokeMethod('sendData', {
        'peerId': peerId,
        'data': data,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to send via peripheral: ${e.message}');
    }
  }

  // ── Foreground Service ───────────────────────────────────────────────

  /// Start Android foreground service for persistent background BLE.
  Future<void> startForegroundService() async {
    try {
      await _methodChannel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      throw Exception('Failed to start foreground service: ${e.message}');
    }
  }

  /// Stop the foreground service.
  Future<void> stopForegroundService() async {
    try {
      await _methodChannel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      throw Exception('Failed to stop foreground service: ${e.message}');
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _isActive = false;

    await stopScanning();
    await stopAdvertising();

    _peripheralEventSubscription?.cancel();
    for (final sub in _notifySubscriptions.values) {
      sub.cancel();
    }
    _notifySubscriptions.clear();

    // Disconnect all central-mode connections
    for (final device in _fbpDevices.values) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _fbpDevices.clear();
    _connectedPeers.clear();

    await _incomingDataCtrl.close();
    await _peerDiscoveredCtrl.close();
    await _peerLostCtrl.close();
  }
}
