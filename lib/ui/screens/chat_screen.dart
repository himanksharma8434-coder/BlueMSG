import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/mesh_service.dart';
import '../../storage/models/stored_message.dart';
import '../theme/app_theme.dart';

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
  StreamSubscription? _msgSubscription;

  bool get isBroadcast => widget.conversationId == 'broadcast';

  @override
  void initState() {
    super.initState();
    _loadHistory();

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

  Future<void> _loadHistory() async {
    final history = await widget.meshService.messageRepo
        .getConversationHistory(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
            Text(widget.peerNickname),
            Row(
              children: [
                Icon(
                  isBroadcast
                      ? Icons.cell_tower_rounded
                      : (isPeerConnected ? Icons.bluetooth_connected : Icons.schedule),
                  size: 12,
                  color: isPeerConnected ? AppTheme.accentMint : AppTheme.accentAmber,
                ),
                const SizedBox(width: 4),
                Text(
                  isBroadcast
                      ? 'Public Broadcast'
                      : (isPeerConnected
                          ? 'Connected in BLE Range'
                          : 'Store & Forward Outbox'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isPeerConnected ? AppTheme.accentMint : AppTheme.accentAmber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Security / E2E Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBroadcast ? Icons.public : Icons.lock_outline_rounded,
                  size: 14,
                  color: isBroadcast ? AppTheme.primaryPurple : AppTheme.primaryCyan,
                ),
                const SizedBox(width: 6),
                Text(
                  isBroadcast
                      ? 'Broadcast messages are cleartext & signed by sender'
                      : 'End-to-End Encrypted via X25519 + ChaCha20-Poly1305',
                  style: TextStyle(
                    fontSize: 11,
                    color: isBroadcast ? AppTheme.primaryPurple : AppTheme.primaryCyan,
                  ),
                ),
              ],
            ),
          ),

          // Message Timeline List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          isBroadcast
                              ? 'No broadcast messages yet.\nType a message to send to all nearby devices.'
                              : 'No messages yet.\nSend a message to start direct chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: isBroadcast
                          ? 'Broadcast to mesh...'
                          : 'Send encrypted message...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(StoredMessage msg) {
    final isMe = msg.direction == MessageDirection.outgoing;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppTheme.primaryCyan.withOpacity(0.3) : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && isBroadcast)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Sender: ${msg.senderId}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Text(
              msg.body,
              style: const TextStyle(fontSize: 14, color: Colors.white),
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
        return const Icon(Icons.schedule, size: 12, color: AppTheme.accentAmber);
      case DeliveryStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case DeliveryStatus.relayed:
        return const Icon(Icons.alt_route_rounded, size: 12, color: AppTheme.primaryCyan);
      case DeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: AppTheme.accentMint);
      case DeliveryStatus.read:
        return const Icon(Icons.remove_red_eye_rounded, size: 12, color: AppTheme.primaryCyan);
      case DeliveryStatus.failed:
        return const Icon(Icons.error_outline, size: 12, color: AppTheme.accentRose);
    }
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
