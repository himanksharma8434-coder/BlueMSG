import 'dart:async';
import 'dart:typed_data';
import 'transport_interface.dart';

/// In-memory mock transport for testing on Desktop/Web or without physical BLE hardware.
class MockTransport implements Transport {
  bool _isActive = false;
  final Set<String> _connectedPeers = {};

  final StreamController<({String peerId, Uint8List data})> _incomingDataCtrl =
      StreamController.broadcast();
  final StreamController<DiscoveredPeer> _peerDiscoveredCtrl =
      StreamController.broadcast();
  final StreamController<String> _peerLostCtrl = StreamController.broadcast();

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

  @override
  Future<void> startAdvertising() async {
    _isActive = true;
  }

  @override
  Future<void> stopAdvertising() async {
    _isActive = false;
  }

  @override
  Future<void> startScanning() async {
    _isActive = true;
  }

  @override
  Future<void> stopScanning() async {
    _isActive = false;
  }

  @override
  Future<void> send(String peerId, Uint8List data) async {
    // Mock sending bytes
  }

  @override
  Future<void> broadcast(Uint8List data) async {
    // Mock broadcast bytes
  }

  /// Simulate discovering a peer.
  void simulatePeerDiscovered(String peerId, {String? name, int rssi = -65}) {
    _connectedPeers.add(peerId);
    _peerDiscoveredCtrl.add(DiscoveredPeer(
      peerId: peerId,
      name: name,
      rssi: rssi,
      discoveredAt: DateTime.now(),
    ));
  }

  /// Simulate receiving raw data from a peer.
  void simulateIncomingData(String peerId, Uint8List data) {
    _incomingDataCtrl.add((peerId: peerId, data: data));
  }

  /// Simulate losing a peer.
  void simulatePeerLost(String peerId) {
    _connectedPeers.remove(peerId);
    _peerLostCtrl.add(peerId);
  }

  @override
  Future<void> dispose() async {
    _isActive = false;
    _connectedPeers.clear();
    await _incomingDataCtrl.close();
    await _peerDiscoveredCtrl.close();
    await _peerLostCtrl.close();
  }
}
