import 'dart:typed_data';
import '../cache/dedup_cache.dart';
import '../models/message_envelope.dart';

/// Result of evaluating an incoming message envelope.
class RelayDecision {
  final bool shouldDisplayLocally;
  final MessageEnvelope? envelopeToRebroadcast;
  final bool isDropped;
  final String? dropReason;

  const RelayDecision({
    required this.shouldDisplayLocally,
    this.envelopeToRebroadcast,
    this.isDropped = false,
    this.dropReason,
  });

  factory RelayDecision.drop(String reason) {
    return RelayDecision(
      shouldDisplayLocally: false,
      envelopeToRebroadcast: null,
      isDropped: true,
      dropReason: reason,
    );
  }

  @override
  String toString() {
    return 'RelayDecision(display: $shouldDisplayLocally, rebroadcast: ${envelopeToRebroadcast != null}, dropped: $isDropped, reason: $dropReason)';
  }
}

/// Signature verifier callback: given senderId, signableBytes, and signature, returns bool.
typedef SignatureVerifier = Future<bool> Function({
  required String senderId,
  required Uint8List signableBytes,
  required Uint8List signature,
});

/// Protocol engine responsible for relay and routing decisions.
class RelayEngine {
  final String myDeviceId;
  final DedupCache dedupCache;
  final SignatureVerifier? signatureVerifier;

  RelayEngine({
    required this.myDeviceId,
    required this.dedupCache,
    this.signatureVerifier,
  });

  /// Evaluates an incoming [MessageEnvelope].
  Future<RelayDecision> evaluate(MessageEnvelope envelope) async {
    // 1. Check if message was already seen
    if (dedupCache.hasSeen(envelope.messageId)) {
      return RelayDecision.drop('Duplicate message ID');
    }

    // 2. Mark as seen in cache
    dedupCache.add(envelope.messageId);

    // 3. Verify signature if verifier provided
    if (signatureVerifier != null) {
      final isValidSig = await signatureVerifier!(
        senderId: envelope.senderId,
        signableBytes: envelope.getSignableBytes(),
        signature: envelope.signature,
      );
      if (!isValidSig) {
        return RelayDecision.drop('Invalid cryptographic signature');
      }
    }

    // 4. Check if message is intended for display on this device
    // Matches if recipientId is null (broadcast) OR matches myDeviceId
    final isForMe = (envelope.recipientId == null || envelope.recipientId == myDeviceId);

    // 5. Determine rebroadcast suitability
    // Rebroadcast if TTL > 0 (even if sent by another node)
    MessageEnvelope? rebroadcastEnvelope;
    if (envelope.ttl > 0) {
      rebroadcastEnvelope = envelope.copyWithDecrementedTtl();
    }

    // If not for me and TTL reached 0, it gets dropped
    if (!isForMe && rebroadcastEnvelope == null) {
      return RelayDecision.drop('TTL expired (0)');
    }

    return RelayDecision(
      shouldDisplayLocally: isForMe,
      envelopeToRebroadcast: rebroadcastEnvelope,
      isDropped: false,
    );
  }
}
