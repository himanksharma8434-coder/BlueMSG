import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  final Map<String, int> _peerMtu = {}; // Per-peer negotiated MTU

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
  final Map<String, StreamSubscription> _connectionStateSubscriptions = {};

  // Reconnection tracking
  final Map<String, int> _reconnectAttempts = {};
  static const int _maxReconnectAttempts = 3;

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
        debugPrint('BLE: Permissions not granted for advertising');
        return;
      }
      await _methodChannel.invokeMethod('startAdvertising');
      _listenToPeripheralEvents();
    } catch (e) {
      debugPrint('BLE: Failed to start advertising: $e');
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
          _reconnectAttempts.remove(peerId);
          _peerDiscoveredCtrl.add(DiscoveredPeer(
            peerId: peerId,
            discoveredAt: DateTime.now(),
          ));
          break;

        case 'peerDisconnected':
          final peerId = event['peerId'] as String? ?? 'unknown';
          _connectedPeers.remove(peerId);
          _peerMtu.remove(peerId);
          _peerLostCtrl.add(peerId);
          break;
      }
    }, onError: (e) {
      debugPrint('BLE: Peripheral event error: $e');
    });
  }

  // ── Scanning (Central Mode — flutter_blue_plus) ──────────────────────

  @override
  Future<void> startScanning() async {
    _isActive = true;

    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        debugPrint('BLE: Permissions not granted for scanning');
        return;
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            _handleScanResult(result);
          }
        },
        onError: (e) {
          debugPrint('BLE: Scan error: $e');
        },
      );

      // Start BLE scan filtered by our service UUID
      try {
        await FlutterBluePlus.startScan(
          withServices: [Guid(BleConstants.serviceUuid)],
          androidUsesFineLocation: true,
          continuousUpdates: true,
          continuousDivisor: 1,
        );
      } catch (e) {
        debugPrint('BLE: Filtered scan failed ($e), falling back to unfiltered');
        // Fallback to unfiltered scan if hardware filter fails
        await FlutterBluePlus.startScan(
          androidUsesFineLocation: true,
          continuousUpdates: true,
          continuousDivisor: 1,
        );
      }
    } catch (e) {
      debugPrint('BLE: Failed to start scanning: $e');
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

    // Discover peer if not already connected or update RSSI
    final isNewPeer = !_connectedPeers.contains(peerId);
    if (isNewPeer) {
      _connectedPeers.add(peerId);
      _fbpDevices[peerId] = device;
      _peerDiscoveredCtrl.add(DiscoveredPeer(
        peerId: peerId,
        name: device.platformName.isNotEmpty ? device.platformName : 'bitmsg Peer (${peerId.substring(0, 4)})',
        rssi: result.rssi,
        discoveredAt: DateTime.now(),
      ));

      // Auto-connect and discover GATT services
      _connectAndDiscover(device, peerId);
    } else {
      // Update RSSI and timestamp for active peer
      _peerDiscoveredCtrl.add(DiscoveredPeer(
        peerId: peerId,
        name: device.platformName.isNotEmpty ? device.platformName : 'bitmsg Peer (${peerId.substring(0, 4)})',
        rssi: result.rssi,
        discoveredAt: DateTime.now(),
      ));
    }
  }

  final Map<String, BluetoothCharacteristic> _writeCharacteristics = {};

  /// Connect to a discovered peer, negotiate MTU, discover the mesh service,
  /// subscribe to notifications.
  Future<void> _connectAndDiscover(BluetoothDevice device, String peerId) async {
    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      // Cancel any existing connection state subscription to prevent leaks (HIGH-3)
      _connectionStateSubscriptions[peerId]?.cancel();

      // Listen for disconnection
      _connectionStateSubscriptions[peerId] = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _cleanupPeer(peerId);
          _peerLostCtrl.add(peerId);
          // Attempt reconnection with exponential backoff (HIGH-2)
          _scheduleReconnect(device, peerId);
        }
      });

      // Negotiate MTU — request maximum, the stack will negotiate down (HIGH-1)
      try {
        final mtu = await device.requestMtu(512);
        _peerMtu[peerId] = mtu;
        debugPrint('BLE: Negotiated MTU=$mtu for $peerId');
      } catch (e) {
        debugPrint('BLE: MTU negotiation failed for $peerId: $e');
        _peerMtu[peerId] = 23; // Default BLE MTU
      }

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.str.toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.str.toLowerCase();

            // Cache the write characteristic for fast instantaneous sending
            if (charUuid == BleConstants.writeCharUuid.toLowerCase()) {
              _writeCharacteristics[peerId] = char;
            }

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

      // Reset reconnection counter on successful connection
      _reconnectAttempts.remove(peerId);
    } catch (e) {
      debugPrint('BLE: Connection failed for $peerId: $e');
      _cleanupPeer(peerId);
    }
  }

  /// Clean up all state associated with a disconnected peer.
  void _cleanupPeer(String peerId) {
    _connectedPeers.remove(peerId);
    _fbpDevices.remove(peerId);
    _writeCharacteristics.remove(peerId);
    _peerMtu.remove(peerId);
    _notifySubscriptions[peerId]?.cancel();
    _notifySubscriptions.remove(peerId);
    _connectionStateSubscriptions[peerId]?.cancel();
    _connectionStateSubscriptions.remove(peerId);
  }

  /// Schedule a reconnection attempt with exponential backoff (HIGH-2).
  void _scheduleReconnect(BluetoothDevice device, String peerId) {
    final attempts = _reconnectAttempts[peerId] ?? 0;
    if (attempts >= _maxReconnectAttempts) {
      debugPrint('BLE: Max reconnect attempts reached for $peerId');
      _reconnectAttempts.remove(peerId);
      return;
    }

    _reconnectAttempts[peerId] = attempts + 1;
    final delaySeconds = (1 << attempts).clamp(1, 8); // 1s, 2s, 4s

    Future.delayed(Duration(seconds: delaySeconds), () async {
      if (_connectedPeers.contains(peerId)) return; // Already reconnected via scan
      debugPrint('BLE: Reconnect attempt ${attempts + 1}/$_maxReconnectAttempts for $peerId');
      try {
        _fbpDevices[peerId] = device;
        await _connectAndDiscover(device, peerId);
      } catch (e) {
        debugPrint('BLE: Reconnect failed for $peerId: $e');
      }
    });
  }

  /// Get the negotiated MTU for a peer. Defaults to 23 if unknown.
  int getMtuForPeer(String peerId) {
    return _peerMtu[peerId] ?? 23;
  }

  // ── Sending Data ─────────────────────────────────────────────────────

  @override
  Future<void> send(String peerId, Uint8List data) async {
    // 1. Try central-mode write if peerId is a connected MAC address with cached characteristic
    final device = _fbpDevices[peerId];
    if (device != null && _writeCharacteristics.containsKey(peerId)) {
      try {
        await _writeViaCentral(device, data);
        return;
      } catch (e) {
        debugPrint('BLE: Central-mode send failed for $peerId: $e');
      }
    }

    // 2. Try sending via native peripheral-side (peer connected to our GATT server)
    try {
      await _writeViaPeripheral(peerId, data);
      return;
    } catch (e) {
      debugPrint('BLE: Peripheral-mode send failed for $peerId: $e');
    }

    // 3. Mesh flood fallback: The peerId is a mesh deviceId (UUID) that doesn't map
    //    to any known BLE MAC address. Push the envelope to every connected BLE link
    //    and let the protocol layer (dedup cache + relay engine) handle delivery.
    //    This is the expected path for multi-hop messages where sender ≠ direct neighbor.
    try {
      await _methodChannel.invokeMethod('broadcastData', {'data': data});
    } catch (_) {}

    final peers = List<String>.from(_connectedPeers);
    for (final pid in peers) {
      if (pid == peerId) continue; // Already tried direct above
      final dev = _fbpDevices[pid];
      if (dev != null && _writeCharacteristics.containsKey(pid)) {
        try {
          await _writeViaCentral(dev, data);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> broadcast(Uint8List data) async {
    // 1. Broadcast via native peripheral GATT server (notifies all connected centrals)
    try {
      await _methodChannel.invokeMethod('broadcastData', {'data': data});
    } catch (_) {}

    // 2. Write to all connected central-mode devices directly
    final peers = List<String>.from(_connectedPeers);
    for (final peerId in peers) {
      final device = _fbpDevices[peerId];
      if (device != null && _writeCharacteristics.containsKey(peerId)) {
        try {
          await _writeViaCentral(device, data);
        } catch (_) {}
      }
    }
  }

  /// Write data to a peer's GATT server writable characteristic (central mode).
  /// Only uses cached characteristic — does NOT re-discover services (MED-10 fix).
  Future<void> _writeViaCentral(BluetoothDevice device, Uint8List data) async {
    final peerId = device.remoteId.str;
    final char = _writeCharacteristics[peerId];

    if (char != null) {
      await char.write(data, withoutResponse: true);
      return;
    }
    throw Exception('Mesh write characteristic not cached for peer $peerId');
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

    for (final sub in _connectionStateSubscriptions.values) {
      sub.cancel();
    }
    _connectionStateSubscriptions.clear();

    _reconnectAttempts.clear();

    // Disconnect all central-mode connections
    for (final device in _fbpDevices.values) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _fbpDevices.clear();
    _connectedPeers.clear();
    _peerMtu.clear();

    await _incomingDataCtrl.close();
    await _peerDiscoveredCtrl.close();
    await _peerLostCtrl.close();
  }
}
