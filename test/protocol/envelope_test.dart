import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitmsg/protocol/models/message_envelope.dart';
import 'package:bitmsg/protocol/serialization/envelope_serializer.dart';

void main() {
  group('MessageEnvelope & EnvelopeSerializer Tests', () {
    test('CBOR round-trip serialization for broadcast envelope', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5, 100, 200, 255]);
      final signature = Uint8List.fromList(List.generate(64, (i) => i));

      final envelope = MessageEnvelope.create(
        senderId: 'device-12345678',
        recipientId: null, // Broadcast
        ttl: 6,
        payload: payload,
        signature: signature,
      );

      final encoded = EnvelopeSerializer.encode(envelope);
      expect(encoded, isNotEmpty);

      final decoded = EnvelopeSerializer.decode(encoded);
      expect(decoded.messageId, equals(envelope.messageId));
      expect(decoded.senderId, equals(envelope.senderId));
      expect(decoded.recipientId, isNull);
      expect(decoded.ttl, equals(6));
      expect(decoded.timestamp, equals(envelope.timestamp));
      expect(decoded.payload, equals(payload));
      expect(decoded.signature, equals(signature));
      expect(decoded, equals(envelope));
    });

    test('CBOR round-trip serialization for direct message envelope', () {
      final payload = Uint8List.fromList([10, 20, 30]);
      final signature = Uint8List.fromList(List.generate(64, (i) => 255 - i));

      final envelope = MessageEnvelope.create(
        senderId: 'alice-device-id',
        recipientId: 'bob-device-id',
        ttl: 4,
        payload: payload,
        signature: signature,
      );

      final encoded = EnvelopeSerializer.encode(envelope);
      final decoded = EnvelopeSerializer.decode(encoded);

      expect(decoded.senderId, equals('alice-device-id'));
      expect(decoded.recipientId, equals('bob-device-id'));
      expect(decoded.ttl, equals(4));
      expect(decoded, equals(envelope));
    });

    test('copyWithDecrementedTtl works as expected', () {
      final envelope = MessageEnvelope.create(
        senderId: 'alice',
        ttl: 5,
        payload: Uint8List(0),
        signature: Uint8List(64),
      );

      final decremented = envelope.copyWithDecrementedTtl();
      expect(decremented.ttl, equals(4));
      expect(decremented.messageId, equals(envelope.messageId));

      final zeroTtl = MessageEnvelope.create(
        senderId: 'alice',
        ttl: 0,
        payload: Uint8List(0),
        signature: Uint8List(64),
      );

      expect(zeroTtl.copyWithDecrementedTtl().ttl, equals(0));
    });

    test('getSignableBytes is deterministic and contains envelope fields', () {
      final envelope = MessageEnvelope.create(
        messageId: 'fixed-msg-id-1234',
        senderId: 'sender-1',
        recipientId: 'recipient-1',
        ttl: 5,
        timestamp: 1700000000000,
        payload: Uint8List.fromList([1, 2, 3]),
        signature: Uint8List(64),
      );

      final bytes1 = envelope.getSignableBytes();
      final bytes2 = envelope.getSignableBytes();

      expect(bytes1, equals(bytes2));
      expect(bytes1, isNotEmpty);
    });
  });
}
