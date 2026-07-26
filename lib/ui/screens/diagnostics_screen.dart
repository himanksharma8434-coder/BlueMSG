import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: AppTheme.accentRose),
            SizedBox(width: 8),
            Text('Purge Outbox?'),
          ],
        ),
        content: const Text(
          'This will remove all expired pending messages that could not be delivered to nearby devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purge'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      final count = await widget.meshService.pendingRepo.purgeExpired();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purged $count expired pending messages from outbox.'),
          ),
        );
        _loadStats();
      }
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
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadStats();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIdentityCard(),
                const SizedBox(height: 14),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.accentRose,
                      elevation: 0,
                      side: const BorderSide(color: AppTheme.accentRose),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _purgeOutbox,
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: const Text(
                      'Purge Expired Outbox Messages',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIdentityCard() {
    final devId = _stats['deviceId'] ?? 'Unknown';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: AppTheme.primaryCyan.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fingerprint, color: AppTheme.primaryCyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Cryptographic Identity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Spacer(),
              Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.accentMint,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              devId,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ed25519 Signatures + X25519 Key Exchange Active',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: 18,
        borderColor: color.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
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
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
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
    );
  }
}
