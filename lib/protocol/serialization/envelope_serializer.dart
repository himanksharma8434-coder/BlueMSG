import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import '../models/message_envelope.dart';

/// Compact CBOR serializer for MessageEnvelope.
class EnvelopeSerializer {
  static const int _kMessageId = 0;
  static const int _kSenderId = 1;
  static const int _kRecipientId = 2;
  static const int _kTtl = 3;
  static const int _kTimestamp = 4;
  static const int _kPayload = 5;
  static const int _kSignature = 6;

  /// Encodes a MessageEnvelope into compact binary CBOR bytes.
  static Uint8List encode(MessageEnvelope envelope) {
    final map = <CborValue, CborValue>{
      CborSmallInt(_kMessageId): CborString(envelope.messageId),
      CborSmallInt(_kSenderId): CborString(envelope.senderId),
      if (envelope.recipientId != null)
        CborSmallInt(_kRecipientId): CborString(envelope.recipientId!)
      else
        CborSmallInt(_kRecipientId): const CborNull(),
      CborSmallInt(_kTtl): CborSmallInt(envelope.ttl),
      CborSmallInt(_kTimestamp): CborInt(BigInt.from(envelope.timestamp)),
      CborSmallInt(_kPayload): CborBytes(envelope.payload),
      CborSmallInt(_kSignature): CborBytes(envelope.signature),
    };

    return Uint8List.fromList(cbor.encode(CborMap(map)));
  }

  /// Decodes binary CBOR bytes into a MessageEnvelope.
  static MessageEnvelope decode(Uint8List bytes) {
    final CborValue decoded = cbor.decode(bytes);
    if (decoded is! CborMap) {
      throw const FormatException('Invalid CBOR data: expected CborMap');
    }

    final map = decoded.map;

    String? getOptionalString(int key) {
      final value = map[CborSmallInt(key)];
      if (value is CborString) {
        return value.toString();
      }
      return null;
    }

    String getString(int key) {
      final val = getOptionalString(key);
      if (val == null) {
        throw FormatException('Missing required string field for key $key');
      }
      return val;
    }

    int getInt(int key) {
      final value = map[CborSmallInt(key)];
      if (value is CborInt) {
        return value.toInt();
      }
      throw FormatException('Missing or invalid int field for key $key');
    }

    Uint8List getBytes(int key) {
      final value = map[CborSmallInt(key)];
      if (value is CborBytes) {
        return Uint8List.fromList(value.bytes);
      }
      throw FormatException('Missing or invalid bytes field for key $key');
    }

    return MessageEnvelope(
      messageId: getString(_kMessageId),
      senderId: getString(_kSenderId),
      recipientId: getOptionalString(_kRecipientId),
      ttl: getInt(_kTtl),
      timestamp: getInt(_kTimestamp),
      payload: getBytes(_kPayload),
      signature: getBytes(_kSignature),
    );
  }
}
