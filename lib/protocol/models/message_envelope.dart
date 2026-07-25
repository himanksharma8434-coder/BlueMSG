import 'dart:typed_data';
import 'package:uuid/uuid.dart';

/// Representation of a single message envelope in the mesh network.
class MessageEnvelope {
  final String messageId;
  final String senderId;
  final String? senderNickname;
  final Uint8List? senderPublicKey; // Ed25519 public key bytes (32 bytes)
  final Uint8List? senderEncryptionKey; // X25519 public key bytes (32 bytes)
  final String? recipientId;
  final int ttl;
  final int timestamp;
  final Uint8List payload;
  final Uint8List signature;

  const MessageEnvelope({
    required this.messageId,
    required this.senderId,
    this.senderNickname,
    this.senderPublicKey,
    this.senderEncryptionKey,
    this.recipientId,
    this.ttl = 6,
    required this.timestamp,
    required this.payload,
    required this.signature,
  });

  /// Factory to generate a new envelope with a unique UUID v4 ID and current timestamp.
  factory MessageEnvelope.create({
    required String senderId,
    String? senderNickname,
    Uint8List? senderPublicKey,
    Uint8List? senderEncryptionKey,
    String? recipientId,
    int ttl = 6,
    required Uint8List payload,
    required Uint8List signature,
    String? messageId,
    int? timestamp,
  }) {
    return MessageEnvelope(
      messageId: messageId ?? const Uuid().v4(),
      senderId: senderId,
      senderNickname: senderNickname,
      senderPublicKey: senderPublicKey,
      senderEncryptionKey: senderEncryptionKey,
      recipientId: recipientId,
      ttl: ttl,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: payload,
      signature: signature,
    );
  }

  /// Creates a copy of this envelope with a decremented TTL.
  MessageEnvelope copyWithDecrementedTtl() {
    return MessageEnvelope(
      messageId: messageId,
      senderId: senderId,
      senderNickname: senderNickname,
      senderPublicKey: senderPublicKey,
      senderEncryptionKey: senderEncryptionKey,
      recipientId: recipientId,
      ttl: ttl > 0 ? ttl - 1 : 0,
      timestamp: timestamp,
      payload: payload,
      signature: signature,
    );
  }

  /// Utility to get bytes to sign or verify signature against.
  /// Standardized format: messageId | senderId | senderNickname | recipientId | ttl | timestamp | payload
  Uint8List getSignableBytes() {
    final builder = BytesBuilder();
    builder.add(Uint8List.fromList(messageId.codeUnits));
    builder.add(Uint8List.fromList(senderId.codeUnits));
    if (senderNickname != null) {
      builder.add(Uint8List.fromList(senderNickname!.codeUnits));
    }
    if (recipientId != null) {
      builder.add(Uint8List.fromList(recipientId!.codeUnits));
    }
    final ttlByte = Uint8List(1)..[0] = ttl & 0xFF;
    builder.add(ttlByte);

    final tsBytes = ByteData(8)..setInt64(0, timestamp, Endian.big);
    builder.add(tsBytes.buffer.asUint8List());

    builder.add(payload);
    return builder.toBytes();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageEnvelope &&
        other.messageId == messageId &&
        other.senderId == senderId &&
        other.senderNickname == senderNickname &&
        other.recipientId == recipientId &&
        other.ttl == ttl &&
        other.timestamp == timestamp &&
        _bytesEqual(other.payload, payload) &&
        _bytesEqual(other.signature, signature);
  }

  @override
  int get hashCode {
    return Object.hash(
      messageId,
      senderId,
      senderNickname,
      recipientId,
      ttl,
      timestamp,
      Object.hashAll(payload),
      Object.hashAll(signature),
    );
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'MessageEnvelope(id: $messageId, sender: $senderId, nickname: $senderNickname, recipient: $recipientId, ttl: $ttl, timestamp: $timestamp, payloadLength: ${payload.length})';
  }
}
