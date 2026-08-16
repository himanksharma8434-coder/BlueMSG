import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../protocol/models/crisis_supply_payload.dart';
import '../../services/mesh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/crisis_supply_dialog.dart';
import 'chat_screen.dart';
import 'crisis_hub_screen.dart';
import 'diagnostics_screen.dart';
import 'nearby_peers_screen.dart';

class ConversationListScreen extends StatefulWidget {
  final MeshService meshService;

  const ConversationListScreen({super.key, required this.meshService});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _conversations = [];
  List<CrisisSupplyPayload> _crisisBeacons = [];
  bool _isLoading = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadConversations();
    widget.meshService.addListener(_onMeshUpdated);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.meshService.removeListener(_onMeshUpdated);
    super.dispose();
  }

  void _onMeshUpdated() {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final list = await widget.meshService.messageRepo.getConversationList();
    final beacons = await widget.meshService.getCrisisBeacons();
    if (mounted) {
      setState(() {
        _conversations = list;
        _crisisBeacons = beacons;
        _isLoading = false;
      });
    }
  }

  int get _criticalCount =>
      _crisisBeacons.where((b) => b.urgency == CrisisUrgency.critical).length;

  void _editNicknameDialog() {
    final controller = TextEditingController(
      text: widget.meshService.currentIdentity?.nickname ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppTheme.primaryCyan, size: 20),
            SizedBox(width: 8),
            Text('Edit Display Name'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new display name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black,
            ),
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

  void _navigateToChat(String conversationId, String peerNickname) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, anim, secondaryAnim) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: ChatScreen(
            meshService: widget.meshService,
            conversationId: conversationId,
            peerNickname: peerNickname,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.meshService.currentIdentity?.deviceId ?? '----';
    final myNickname = widget.meshService.currentIdentity?.nickname ??
        'User-${myId.substring(0, 4)}';
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
                  boxShadow: AppTheme.cyanGlow(blur: 8, opacity: 0.3),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit,
                          size: 12,
                          color: AppTheme.primaryCyan,
                        ),
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
            icon: Badge(
              isLabelVisible: _criticalCount > 0,
              backgroundColor: AppTheme.sosRed,
              label: Text('$_criticalCount'),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: AppTheme.sosRed,
              ),
            ),
            tooltip: 'Crisis & SOS Relief Hub',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CrisisHubScreen(meshService: widget.meshService),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Mesh Diagnostics',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(
                    meshService: widget.meshService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryCyan,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          await _loadConversations();
        },
        child: Column(
          children: [
            // Critical Emergency Banner (if any active in mesh)
            if (_criticalCount > 0)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CrisisHubScreen(meshService: widget.meshService),
                    ),
                  );
                },
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.sosRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.sosRed, width: 1.5),
                    boxShadow: AppTheme.sosGlow(blur: 8, opacity: 0.3),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.sosRed, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🚨 $_criticalCount CRITICAL SOS BEACON(S) IN MESH!\nTap to open Disaster & SOS Hub',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppTheme.sosRed, size: 14),
                    ],
                  ),
                ),
              ),

            // Disaster Relief & SOS Hub Hero Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF24101A), Color(0xFF101E2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.sosRed.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.sosGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.sosGlow(blur: 8, opacity: 0.3),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Disaster & SOS Hub',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Offline Supplies: Medic, Food, Water, Shelter, Rescue, Power',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[300],
                          ),
                        ),
                        if (_crisisBeacons.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_crisisBeacons.length} active relief beacons in range',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryCyan,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sosRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CrisisHubScreen(meshService: widget.meshService),
                        ),
                      );
                    },
                    child: const Text(
                      'OPEN HUB',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // iOS Background Warning Banner
            if (!kIsWeb && Platform.isIOS)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentAmber),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.accentAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'iOS Background Mode: Keep bitmsg open for best mesh relay coverage.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.amber[200]),
                      ),
                    ),
                  ],
                ),
              ),

            // Mesh Status Header Bar
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: AppTheme.glassDecoration(
                borderRadius: 16,
                borderColor: AppTheme.cardBorder,
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.accentMint,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentMint.withValues(
                                alpha: 0.2 + (_pulseController.value * 0.6),
                              ),
                              blurRadius: 6 + (_pulseController.value * 6),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BLE Mesh Active',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NearbyPeersScreen(
                            meshService: widget.meshService,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bluetooth_searching,
                            size: 14,
                            color: AppTheme.primaryCyan,
                          ),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryCyan,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Pinned Broadcast Room Tile
                        _buildConversationTile(
                          conversationId: 'broadcast',
                          title: 'Public Broadcast Room',
                          subtitle: _getLastMessageFor('broadcast') ??
                              'Open mesh channel for all nearby devices',
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
                        if (_conversations
                            .where((c) => c['conversationId'] != 'broadcast')
                            .isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 24,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 40,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No direct messages yet.\nTap "Discover Peers" to start a 1-on-1 chat.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._conversations
                              .where((c) => c['conversationId'] != 'broadcast')
                              .map((conv) => _buildConversationTile(
                                    conversationId:
                                        conv['conversationId'] as String,
                                    title: conv['peerNickname'] ??
                                        'Peer: ${conv['conversationId']}',
                                    subtitle: conv['lastMessage'] ?? '',
                                    isBroadcast: false,
                                    icon: Icons.person_rounded,
                                  )),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NearbyPeersScreen(
                meshService: widget.meshService,
              ),
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
      final conv = _conversations.firstWhere(
        (c) => c['conversationId'] == conversationId,
      );
      final last = conv['lastMessage'] as String?;
      if (last == null) return null;
      final parsed = CrisisSupplyPayload.tryParse(last);
      if (parsed != null) {
        final tag = parsed.type == CrisisRequestType.request ? 'NEED' : 'OFFER';
        return '${parsed.category.emoji} [$tag] ${parsed.title}';
      }
      return last;
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
    final isOnline = isBroadcast ||
        widget.meshService.transport.connectedPeers.contains(conversationId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassDecoration(
        borderRadius: 16,
        borderColor: isBroadcast
            ? AppTheme.primaryPurple.withValues(alpha: 0.3)
            : AppTheme.cardBorder,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => _navigateToChat(conversationId, title),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isBroadcast
                  ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                  : AppTheme.primaryCyan.withValues(alpha: 0.2),
              child: Icon(
                icon,
                color: isBroadcast
                    ? AppTheme.primaryPurple
                    : AppTheme.primaryCyan,
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
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentMint.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
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
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}
