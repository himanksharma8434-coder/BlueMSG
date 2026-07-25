import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/mesh_service.dart';

import '../../transport/android/ble_permission_handler.dart';
import '../../transport/transport_interface.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class NearbyPeersScreen extends StatefulWidget {
  final MeshService meshService;

  const NearbyPeersScreen({super.key, required this.meshService});

  @override
  State<NearbyPeersScreen> createState() => _NearbyPeersScreenState();
}

class _NearbyPeersScreenState extends State<NearbyPeersScreen> {
  bool _isLocationEnabled = true;
  bool _hasPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkSystemRequirements();
  }

  Future<void> _checkSystemRequirements() async {
    if (Platform.isAndroid) {
      final locationOk = await BlePermissionHandler.isLocationServiceEnabled();
      final permsOk = await BlePermissionHandler.arePermissionsGranted();
      if (mounted) {
        setState(() {
          _isLocationEnabled = locationOk;
          _hasPermissions = permsOk;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovered Mesh Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkSystemRequirements();
              widget.meshService.transport.startScanning();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (Platform.isAndroid && (!_isLocationEnabled || !_hasPermissions))
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentAmber),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !_hasPermissions
                              ? 'Bluetooth permissions are missing.'
                              : 'Android Location Services (GPS) is turned OFF.\nAndroid OS blocks BLE scanning when Location is OFF.',
                          style: const TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      if (!_hasPermissions) {
                        await BlePermissionHandler.requestAllPermissions();
                      } else {
                        await BlePermissionHandler.openSettings();
                      }
                      _checkSystemRequirements();
                    },
                    child: Text(!_hasPermissions ? 'Grant Permissions' : 'Open Location Settings'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<DiscoveredPeer>>(
              stream: widget.meshService.nearbyPeersStream,
              initialData: widget.meshService.nearbyPeers,
              builder: (context, snapshot) {
                final peers = snapshot.data ?? [];

                if (peers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.radar, size: 64, color: AppTheme.primaryCyan),
                          const SizedBox(height: 16),
                          const Text(
                            'Scanning for nearby BLE mesh nodes...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ensure Bluetooth & Location are ON on both phones running bitmsg.\nDevices will appear automatically in range.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: peers.length,
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
                          child: const Icon(Icons.bluetooth_rounded, color: AppTheme.primaryCyan),
                        ),
                        title: Text(
                          peer.name ?? 'Device: ${peer.peerId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'ID: ${peer.peerId}\nRSSI: ${peer.rssi} dBm',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: AppTheme.primaryCyan,
                            side: const BorderSide(color: AppTheme.primaryCyan),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  meshService: widget.meshService,
                                  conversationId: peer.peerId,
                                  peerNickname: peer.name ?? peer.peerId,
                                ),
                              ),
                            );
                          },
                          child: const Text('Chat'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
