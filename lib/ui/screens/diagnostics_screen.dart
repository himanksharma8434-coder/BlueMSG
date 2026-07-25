import 'package:flutter/material.dart';
import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  final MeshService meshService;

  const DiagnosticsScreen({super.key, required this.meshService});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await widget.meshService.getMeshDiagnostics();
    if (mounted) {
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _purgeOutbox() async {
    final count = await widget.meshService.pendingRepo.purgeExpired();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purged $count expired pending messages from outbox.')),
      );
      _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatCard(
                  title: 'Device Cryptographic Identity',
                  value: _stats['deviceId'] ?? 'Unknown',
                  subtitle: 'Ed25519 / X25519 Keypair Active',
                  icon: Icons.fingerprint,
                  color: AppTheme.primaryCyan,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Connected Peers',
                        value: '${_stats['connectedPeersCount'] ?? 0}',
                        subtitle: 'Direct BLE range',
                        icon: Icons.bluetooth_connected,
                        color: AppTheme.accentMint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Pending Outbox',
                        value: '${_stats['pendingOutboxCount'] ?? 0}',
                        subtitle: 'Store & forward queue',
                        icon: Icons.schedule_send,
                        color: AppTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Sent Messages',
                        value: '${_stats['totalSent'] ?? 0}',
                        subtitle: 'Total authored',
                        icon: Icons.upload_rounded,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Relayed Hops',
                        value: '${_stats['totalRelayed'] ?? 0}',
                        subtitle: 'Mesh store-and-forward',
                        icon: Icons.alt_route_rounded,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Outbox Cleanup Action
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    foregroundColor: AppTheme.accentRose,
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: AppTheme.accentRose),
                  ),
                  onPressed: _purgeOutbox,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Purge Expired Outbox Messages'),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
