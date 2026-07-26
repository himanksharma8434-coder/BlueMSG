import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _NearbyPeersScreenState extends State<NearbyPeersScreen>
    with SingleTickerProviderStateMixin {
  bool _isLocationEnabled = true;
  bool _hasPermissions = true;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkSystemRequirements();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
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

  Widget _buildSignalIndicator(int rssi) {
    int bars = 1;
    if (rssi >= -60) {
      bars = 4;
    } else if (rssi >= -75) {
      bars = 3;
    } else if (rssi >= -88) {
      bars = 2;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final active = index < bars;
        return Container(
          width: 3,
          height: 6.0 + (index * 3),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: active ? AppTheme.accentMint : AppTheme.cardBorder,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
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
              HapticFeedback.selectionClick();
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentAmber),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.accentAmber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          !_hasPermissions
                              ? 'Bluetooth permissions are missing.'
                              : 'Android Location Services (GPS) is turned OFF.\nAndroid OS blocks BLE scanning when Location is OFF.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      if (!_hasPermissions) {
                        await BlePermissionHandler.requestAllPermissions();
                      } else {
                        await BlePermissionHandler.openSettings();
                      }
                      _checkSystemRequirements();
                    },
                    child: Text(
                      !_hasPermissions
                          ? 'Grant Permissions'
                          : 'Open Location Settings',
                    ),
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
                          // Radar pulse visual
                          AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              final val = _radarController.value;
                              return SizedBox(
                                width: 140,
                                height: 140,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 40 + (val * 90),
                                      height: 40 + (val * 90),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primaryCyan
                                              .withValues(alpha: 1.0 - val),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppTheme.primaryGradient,
                                        boxShadow: AppTheme.cyanGlow(
                                          blur: 16,
                                          opacity: 0.4,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.radar,
                                        size: 32,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
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
                            'Ensure Bluetooth & Location are ON on devices running bitmsg.\nDiscovered nodes will appear automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: AppTheme.glassDecoration(
                        borderRadius: 16,
                        borderColor: AppTheme.cardBorder,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppTheme.primaryCyan.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.bluetooth_rounded,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                        title: Text(
                          peer.name ?? 'Device: ${peer.peerId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID: ${peer.peerId}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildSignalIndicator(peer.rssi),
                                const SizedBox(width: 6),
                                Text(
                                  '${peer.rssi} dBm',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: AppTheme.primaryCyan,
                            side: const BorderSide(
                              color: AppTheme.primaryCyan,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
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
