import 'dart:typed_data';

/// Represents a discovered peer on the mesh network.
class DiscoveredPeer {
  final String peerId;
  final String? name;
  final int rssi;
  final DateTime discoveredAt;

  const DiscoveredPeer({
    required this.peerId,
    this.name,
    this.rssi = 0,
    required this.discoveredAt,
  });

  @override
  String toString() => 'DiscoveredPeer(id: $peerId, name: $name, rssi: $rssi)';
}

/// Abstract transport interface that the mesh protocol layer uses.
/// Platform-specific implementations (Android BLE, iOS CoreBluetooth) implement this.
abstract class Transport {
  /// Start advertising this device's presence on the mesh.
  Future<void> startAdvertising();

  /// Stop advertising.
  Future<void> stopAdvertising();

  /// Start scanning for nearby mesh peers.
  Future<void> startScanning();

  /// Stop scanning.
  Future<void> stopScanning();

  /// Send raw data to a specific peer.
  Future<void> send(String peerId, Uint8List data);

  /// Broadcast raw data to all connected/nearby peers.
  Future<void> broadcast(Uint8List data);

  /// Stream of incoming raw data from peers. Emits (peerId, data) tuples.
  Stream<({String peerId, Uint8List data})> get incomingData;

  /// Stream of discovered peers (added/updated).
  Stream<DiscoveredPeer> get peerDiscovered;

  /// Stream of lost peers (no longer in range).
  Stream<String> get peerLost;

  /// Current set of reachable peer IDs.
  Set<String> get connectedPeers;

  /// Whether the transport is currently active (scanning + advertising).
  bool get isActive;

  /// Clean shutdown of all BLE resources.
  Future<void> dispose();
}
