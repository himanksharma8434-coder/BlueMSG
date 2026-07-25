import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitmsg/protocol/cache/dedup_cache.dart';
import 'package:bitmsg/protocol/models/message_envelope.dart';
import 'package:bitmsg/protocol/relay/relay_engine.dart';

void main() {
  group('RelayEngine Decision Matrix Tests', () {
    late DedupCache cache;
    late String myDeviceId;
    late RelayEngine engine;

    setUp(() {
      cache = DedupCache();
      myDeviceId = 'device-node-B';
      engine = RelayEngine(
        myDeviceId: myDeviceId,
        dedupCache: cache,
      );
    });

    test('Broadcast message: should display locally and rebroadcast with decremented TTL', () async {
      final envelope = MessageEnvelope.create(
        messageId: 'bcast-1',
        senderId: 'device-node-A',
        recipientId: null, // Broadcast
        ttl: 5,
        payload: Uint8List.fromList([1, 2, 3]),
        signature: Uint8List(64),
      );

      final decision = await engine.evaluate(envelope);

      expect(decision.isDropped, isFalse);
      expect(decision.shouldDisplayLocally, isTrue);
      expect(decision.envelopeToRebroadcast, isNotNull);
      expect(decision.envelopeToRebroadcast!.ttl, equals(4));
    });

    test('Direct message for ME: should display locally and rebroadcast if TTL > 0', () async {
      final envelope = MessageEnvelope.create(
        messageId: 'direct-me-1',
        senderId: 'device-node-A',
        recipientId: myDeviceId,
        ttl: 3,
        payload: Uint8List.fromList([4, 5, 6]),
        signature: Uint8List(64),
      );

      final decision = await engine.evaluate(envelope);

      expect(decision.isDropped, isFalse);
      expect(decision.shouldDisplayLocally, isTrue);
      expect(decision.envelopeToRebroadcast, isNotNull);
      expect(decision.envelopeToRebroadcast!.ttl, equals(2));
    });

    test('Direct message for ANOTHER device (Node C): should NOT display locally, but SHOULD rebroadcast', () async {
      final envelope = MessageEnvelope.create(
        messageId: 'relay-to-C-1',
        senderId: 'device-node-A',
        recipientId: 'device-node-C',
        ttl: 4,
        payload: Uint8List.fromList([7, 8, 9]),
        signature: Uint8List(64),
      );

      final decision = await engine.evaluate(envelope);

      expect(decision.isDropped, isFalse);
      expect(decision.shouldDisplayLocally, isFalse);
      expect(decision.envelopeToRebroadcast, isNotNull);
      expect(decision.envelopeToRebroadcast!.ttl, equals(3));
    });

    test('Duplicate message: should drop when received a second time', () async {
      final envelope = MessageEnvelope.create(
        messageId: 'repeat-msg-99',
        senderId: 'device-node-A',
        recipientId: myDeviceId,
        ttl: 5,
        payload: Uint8List.fromList([1]),
        signature: Uint8List(64),
      );

      final firstDecision = await engine.evaluate(envelope);
      expect(firstDecision.isDropped, isFalse);

      final secondDecision = await engine.evaluate(envelope);
      expect(secondDecision.isDropped, isTrue);
      expect(secondDecision.dropReason, contains('Duplicate'));
      expect(secondDecision.shouldDisplayLocally, isFalse);
      expect(secondDecision.envelopeToRebroadcast, isNull);
    });

    test('TTL expired (0) message for ANOTHER device: should drop', () async {
      final envelope = MessageEnvelope.create(
        messageId: 'expired-relay-1',
        senderId: 'device-node-A',
        recipientId: 'device-node-C',
        ttl: 0,
        payload: Uint8List.fromList([1, 2]),
        signature: Uint8List(64),
      );

      final decision = await engine.evaluate(envelope);

      expect(decision.isDropped, isTrue);
      expect(decision.dropReason, contains('TTL expired'));
      expect(decision.shouldDisplayLocally, isFalse);
      expect(decision.envelopeToRebroadcast, isNull);
    });

    test('Invalid signature: should drop message', () async {
      final engineWithSigCheck = RelayEngine(
        myDeviceId: myDeviceId,
        dedupCache: DedupCache(),
        signatureVerifier: ({required senderId, required signableBytes, required signature}) async {
          return false; // Signature check failed
        },
      );

      final envelope = MessageEnvelope.create(
        messageId: 'invalid-sig-1',
        senderId: 'device-node-A',
        recipientId: myDeviceId,
        ttl: 5,
        payload: Uint8List.fromList([1, 2, 3]),
        signature: Uint8List(64),
      );

      final decision = await engineWithSigCheck.evaluate(envelope);

      expect(decision.isDropped, isTrue);
      expect(decision.dropReason, contains('Invalid cryptographic signature'));
    });
  });
}
