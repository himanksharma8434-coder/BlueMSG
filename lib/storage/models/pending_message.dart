import 'dart:typed_data';

/// A message queued for store-and-forward delivery.
/// Kept in the outbox until delivered or expired.
class PendingMessage {
  final String messageId;
  final String recipientId;
  final Uint8List envelopeBytes; // Pre-serialized CBOR envelope
  final int createdAt; // epoch millis
  final int retryCount;
  final int? lastAttemptAt; // epoch millis
  final int expiresAt; // epoch millis — drop after this

  const PendingMessage({
    required this.messageId,
    required this.recipientId,
    required this.envelopeBytes,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'recipientId': recipientId,
      'envelopeBytes': envelopeBytes,
      'createdAt': createdAt,
      'retryCount': retryCount,
      'lastAttemptAt': lastAttemptAt,
      'expiresAt': expiresAt,
    };
  }

  factory PendingMessage.fromMap(Map<String, dynamic> map) {
    return PendingMessage(
      messageId: map['messageId'] as String,
      recipientId: map['recipientId'] as String,
      envelopeBytes: map['envelopeBytes'] as Uint8List,
      createdAt: map['createdAt'] as int,
      retryCount: map['retryCount'] as int,
      lastAttemptAt: map['lastAttemptAt'] as int?,
      expiresAt: map['expiresAt'] as int,
    );
  }

  /// Whether this message has expired and should be dropped.
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  PendingMessage copyWithRetry() {
    return PendingMessage(
      messageId: messageId,
      recipientId: recipientId,
      envelopeBytes: envelopeBytes,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      lastAttemptAt: DateTime.now().millisecondsSinceEpoch,
      expiresAt: expiresAt,
    );
  }

  @override
  String toString() {
    return 'PendingMessage(id: $messageId, to: $recipientId, retries: $retryCount, expired: $isExpired)';
  }
}
