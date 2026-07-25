import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'diagnostics_screen.dart';
import 'nearby_peers_screen.dart';

class ConversationListScreen extends StatefulWidget {
  final MeshService meshService;

  const ConversationListScreen({super.key, required this.meshService});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    widget.meshService.addListener(_onMeshUpdated);
  }

  @override
  void dispose() {
    widget.meshService.removeListener(_onMeshUpdated);
    super.dispose();
  }

  void _onMeshUpdated() {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final list = await widget.meshService.messageRepo.getConversationList();
    if (mounted) {
      setState(() {
        _conversations = list;
        _isLoading = false;
      });
    }
  }

  void _editNicknameDialog() {
    final controller = TextEditingController(
      text: widget.meshService.currentIdentity?.nickname ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Your Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new display name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await widget.meshService.updateNickname(newName);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.meshService.currentIdentity?.deviceId ?? '----';
    final myNickname = widget.meshService.currentIdentity?.nickname ?? 'User-${myId.substring(0, 4)}';
    final nearbyCount = widget.meshService.nearbyPeers.length;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editNicknameDialog,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            myNickname,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppTheme.primaryCyan),
                      ],
                    ),
                    Text(
                      'ID: $myId',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Mesh Diagnostics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(meshService: widget.meshService),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // iOS Background Warning Banner
          if (!kIsWeb && Platform.isIOS)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentAmber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.accentAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'iOS Background Mode: Keep bitmsg open for best mesh relay coverage.',
                      style: TextStyle(fontSize: 12, color: Colors.amber[200]),
                    ),
                  ),
                ],
              ),
            ),

          // Mesh Status Bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentMint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'BLE Mesh Active',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NearbyPeersScreen(meshService: widget.meshService),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bluetooth_searching,
                            size: 14, color: AppTheme.primaryCyan),
                        const SizedBox(width: 6),
                        Text(
                          '$nearbyCount nearby',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conversation List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Pinned Broadcast Room Tile
                      _buildConversationTile(
                        conversationId: 'broadcast',
                        title: 'Public Broadcast Room',
                        subtitle: _getLastMessageFor('broadcast') ?? 'Open mesh channel for all nearby devices',
                        isBroadcast: true,
                        icon: Icons.cell_tower_rounded,
                      ),
                      const Divider(color: AppTheme.cardBorder, height: 24),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'DIRECT MESSAGES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (_conversations.where((c) => c['conversationId'] != 'broadcast').isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            'No direct messages yet.\nTap "Discover Peers" to start a 1-on-1 chat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        )
                      else
                        ..._conversations
                            .where((c) => c['conversationId'] != 'broadcast')
                            .map((conv) => _buildConversationTile(
                                  conversationId: conv['conversationId'] as String,
                                  title: conv['peerNickname'] ?? 'Peer: ${conv['conversationId']}',
                                  subtitle: conv['lastMessage'] ?? '',
                                  isBroadcast: false,
                                  icon: Icons.person_rounded,
                                )),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NearbyPeersScreen(meshService: widget.meshService),
            ),
          );
        },
        icon: const Icon(Icons.radar_rounded),
        label: const Text('Discover Peers'),
      ),
    );
  }

  String? _getLastMessageFor(String conversationId) {
    try {
      final conv = _conversations.firstWhere((c) => c['conversationId'] == conversationId);
      return conv['lastMessage'] as String?;
    } catch (_) {
      return null;
    }
  }

  Widget _buildConversationTile({
    required String conversationId,
    required String title,
    required String subtitle,
    required bool isBroadcast,
    required IconData icon,
  }) {
    final isOnline = isBroadcast || widget.meshService.transport.connectedPeers.contains(conversationId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                meshService: widget.meshService,
                conversationId: conversationId,
                peerNickname: title,
              ),
            ),
          );
        },
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isBroadcast
                  ? AppTheme.primaryPurple.withOpacity(0.2)
                  : AppTheme.primaryCyan.withOpacity(0.2),
              child: Icon(
                icon,
                color: isBroadcast ? AppTheme.primaryPurple : AppTheme.primaryCyan,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.accentMint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
