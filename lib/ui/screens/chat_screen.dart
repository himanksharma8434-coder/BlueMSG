import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../protocol/models/crisis_supply_payload.dart';
import '../../services/mesh_service.dart';
import '../../storage/models/stored_message.dart';
import '../theme/app_theme.dart';
import '../widgets/crisis_beacon_card.dart';
import '../widgets/crisis_supply_dialog.dart';
import 'crisis_hub_screen.dart';

class ChatScreen extends StatefulWidget {
  final MeshService meshService;
  final String conversationId; // 'broadcast' or peer deviceId
  final String peerNickname;

  const ChatScreen({
    super.key,
    required this.meshService,
    required this.conversationId,
    required this.peerNickname,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<StoredMessage> _messages = [];
  bool _isLoading = true;
  bool _showScrollToBottom = false;
  StreamSubscription? _msgSubscription;

  bool get isBroadcast => widget.conversationId == 'broadcast';

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final show = _scrollController.offset > 200;
        if (show != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = show;
          });
        }
      }
    });

    // Listen to real-time incoming messages
    _msgSubscription = widget.meshService.onMessageReceived.listen((msg) {
      if (msg.conversationId == widget.conversationId) {
        _loadHistory();
      }
    });

    widget.meshService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    widget.meshService.removeListener(_onServiceUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    _loadHistory();
  }

  final Map<String, String> _peerNicknames = {};

  Future<void> _loadHistory() async {
    final history = await widget.meshService.messageRepo
        .getConversationHistory(widget.conversationId);
    final peers = await widget.meshService.peerRepo.getAllPeers();
    final nicknameMap = <String, String>{};
    for (final p in peers) {
      if (p.nickname != null && p.nickname!.isNotEmpty) {
        nicknameMap[p.deviceId] = p.nickname!;
      }
    }

    if (mounted) {
      setState(() {
        _messages = history;
        _peerNicknames.clear();
        _peerNicknames.addAll(nicknameMap);
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _textController.clear();

    await widget.meshService.sendMessage(
      recipientId: isBroadcast ? null : widget.conversationId,
      body: text,
    );

    await _loadHistory();

    // Scroll to bottom (newest)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPeerConnected = isBroadcast ||
        widget.meshService.transport.connectedPeers
            .contains(widget.conversationId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerNickname,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isPeerConnected
                        ? AppTheme.accentMint
                        : AppTheme.accentAmber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isBroadcast
                      ? 'Public Broadcast Channel'
                      : (isPeerConnected
                          ? 'Connected in BLE Range'
                          : 'Store & Forward Outbox'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isPeerConnected
                        ? AppTheme.accentMint
                        : AppTheme.accentAmber,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.health_and_safety_rounded,
              color: AppTheme.sosRed,
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
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Security / E2E Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.8),
                  border: const Border(
                    bottom: BorderSide(color: AppTheme.cardBorder, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBroadcast ? Icons.public : Icons.lock_outline_rounded,
                      size: 13,
                      color: isBroadcast
                          ? AppTheme.primaryPurple
                          : AppTheme.primaryCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBroadcast
                          ? 'Broadcast messages are cleartext & signed by sender'
                          : 'End-to-End Encrypted via X25519 + ChaCha20-Poly1305',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isBroadcast
                            ? AppTheme.primaryPurple
                            : AppTheme.primaryCyan,
                      ),
                    ),
                  ],
                ),
              ),

              // Message Timeline List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryCyan,
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isBroadcast
                                        ? Icons.cell_tower_rounded
                                        : Icons.lock_clock_outlined,
                                    size: 48,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isBroadcast
                                        ? 'No broadcast messages yet.\nType a message to send to all nearby devices.'
                                        : 'No messages yet.\nSend an encrypted message to start direct chat.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true, // Newest at bottom
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return _buildMessageBubble(msg);
                            },
                          ),
              ),

              // Message Input Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_alert_rounded,
                          color: AppTheme.sosRed,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Request / Offer Supplies (SOS)',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        showDialog(
                          context: context,
                          builder: (_) => CrisisSupplyDialog(
                            meshService: widget.meshService,
                          ),
                        ).then((_) => _loadHistory());
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: isBroadcast
                              ? 'Broadcast to mesh...'
                              : 'Send encrypted message...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cyanGlow(blur: 8, opacity: 0.3),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Scroll-to-bottom FAB
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: AppTheme.surfaceLight,
                foregroundColor: AppTheme.primaryCyan,
                child: const Icon(Icons.arrow_downward_rounded),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(StoredMessage msg) {
    final parsedCrisis = CrisisSupplyPayload.tryParse(msg.body);
    if (parsedCrisis != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CrisisBeaconCard(
          beacon: parsedCrisis,
          meshService: widget.meshService,
          compact: true,
          onUpdated: _loadHistory,
        ),
      );
    }

    final isMe = msg.direction == MessageDirection.outgoing;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.surfaceLight : AppTheme.surface,
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withValues(alpha: 0.25),
                    AppTheme.surfaceLight,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(
            color: isMe
                ? AppTheme.primaryCyan.withValues(alpha: 0.35)
                : AppTheme.cardBorder,
          ),
          boxShadow: isMe
              ? AppTheme.cyanGlow(blur: 6, opacity: 0.1)
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && isBroadcast)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _peerNicknames[msg.senderId] ??
                      'User-${msg.senderId.substring(0, 4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            Text(
              msg.body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  _buildDeliveryIcon(msg.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return const Icon(
          Icons.schedule,
          size: 12,
          color: AppTheme.accentAmber,
        );
      case DeliveryStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case DeliveryStatus.relayed:
        return const Icon(
          Icons.alt_route_rounded,
          size: 12,
          color: AppTheme.primaryCyan,
        );
      case DeliveryStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: AppTheme.accentMint,
        );
      case DeliveryStatus.read:
        return const Icon(
          Icons.remove_red_eye_rounded,
          size: 12,
          color: AppTheme.primaryCyan,
        );
      case DeliveryStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 12,
          color: AppTheme.accentRose,
        );
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
