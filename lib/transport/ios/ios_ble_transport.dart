import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../transport_interface.dart';

/// iOS BLE transport implementation.
///
/// Uses native Swift CoreBluetooth (CBCentralManager + CBPeripheralManager)
/// via platform channels for full dual-mode BLE support.
///
/// ## iOS Background Limitations:
/// - Advertising while backgrounded only broadcasts in the overflow area —
///   non-iOS foreground scanners may not see the full service UUID.
/// - Background scanning only works for pre-declared service UUIDs.
/// - State restoration is enabled but not guaranteed by iOS.
/// - **UX recommendation**: Show a banner telling users mesh works best with the app open.
class IosBleTransport implements Transport {
  static const MethodChannel _methodChannel =
      MethodChannel('com.bitmsg/ble_peripheral');
  static const EventChannel _eventChannel =
      EventChannel('com.bitmsg/ble_peripheral_events');

  bool _isActive = false;
  final Set<String> _connectedPeers = {};

  final StreamController<({String peerId, Uint8List data})> _incomingDataCtrl =
      StreamController.broadcast();
  final StreamController<DiscoveredPeer> _peerDiscoveredCtrl =
      StreamController.broadcast();
  final StreamController<String> _peerLostCtrl = StreamController.broadcast();

  StreamSubscription? _eventSubscription;

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

  /// Start listening to native BLE events.
  void _listenToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen((event) {
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

        case 'peerDiscovered':
          final peerId = event['peerId'] as String? ?? 'unknown';
          final name = event['name'] as String?;
          final rssi = event['rssi'] as int? ?? 0;
          _connectedPeers.add(peerId);
          _peerDiscoveredCtrl.add(DiscoveredPeer(
            peerId: peerId,
            name: name,
            rssi: rssi,
            discoveredAt: DateTime.now(),
          ));
          break;
      }
    });
  }

  @override
  Future<void> startAdvertising() async {
    _listenToEvents();
    await _methodChannel.invokeMethod('startAdvertising');
  }

  @override
  Future<void> stopAdvertising() async {
    await _methodChannel.invokeMethod('stopAdvertising');
  }

  @override
  Future<void> startScanning() async {
    _isActive = true;
    _listenToEvents();
    await _methodChannel.invokeMethod('startScanning');
  }

  @override
  Future<void> stopScanning() async {
    _isActive = false;
    await _methodChannel.invokeMethod('stopScanning');
  }

  @override
  Future<void> send(String peerId, Uint8List data) async {
    await _methodChannel.invokeMethod('sendData', {
      'peerId': peerId,
      'data': data,
    });
  }

  @override
  Future<void> broadcast(Uint8List data) async {
    final peers = List<String>.from(_connectedPeers);
    for (final peerId in peers) {
      try {
        await send(peerId, data);
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _isActive = false;
    _eventSubscription?.cancel();
    await _methodChannel.invokeMethod('stop');
    _connectedPeers.clear();
    await _incomingDataCtrl.close();
    await _peerDiscoveredCtrl.close();
    await _peerLostCtrl.close();
  }
}
