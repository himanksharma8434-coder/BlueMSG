/// Delivery status for stored messages.
enum DeliveryStatus {
  /// Message is queued locally, not yet sent to any peer.
  pending,

  /// Message has been sent (written to at least one BLE peer).
  sent,

  /// Message was relayed by at least one intermediate node.
  relayed,

  /// Message was delivered to the recipient device.
  delivered,

  /// Message was read by the recipient (if read receipts are supported).
  read,

  /// Message delivery failed after all retry attempts.
  failed,
}

/// Direction of a message relative to this device.
enum MessageDirection {
  /// This device authored and sent the message.
  outgoing,

  /// This device received the message.
  incoming,
}

/// A locally-stored chat message.
class StoredMessage {
  final String id; // Same as MessageEnvelope.messageId (UUID)
  final String conversationId; // Peer deviceId for DMs, or a room/broadcast ID
  final String senderId;
  final String? recipientId;
  final String body; // Decrypted plaintext body
  final int timestamp;
  final DeliveryStatus status;
  final MessageDirection direction;

  const StoredMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.recipientId,
    required this.body,
    required this.timestamp,
    required this.status,
    required this.direction,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'recipientId': recipientId,
      'body': body,
      'timestamp': timestamp,
      'status': status.index,
      'direction': direction.index,
    };
  }

  factory StoredMessage.fromMap(Map<String, dynamic> map) {
    return StoredMessage(
      id: map['id'] as String,
      conversationId: map['conversationId'] as String,
      senderId: map['senderId'] as String,
      recipientId: map['recipientId'] as String?,
      body: map['body'] as String,
      timestamp: map['timestamp'] as int,
      status: DeliveryStatus.values[map['status'] as int],
      direction: MessageDirection.values[map['direction'] as int],
    );
  }

  StoredMessage copyWith({DeliveryStatus? status}) {
    return StoredMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      recipientId: recipientId,
      body: body,
      timestamp: timestamp,
      status: status ?? this.status,
      direction: direction,
    );
  }

  @override
  String toString() {
    return 'StoredMessage(id: $id, conv: $conversationId, sender: $senderId, status: ${status.name}, dir: ${direction.name})';
  }
}
