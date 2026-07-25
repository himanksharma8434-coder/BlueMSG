import 'dart:typed_data';
import 'package:cbor/cbor.dart';

/// Data structure representing one chunk of a larger message envelope.
class MessageChunk {
  final String messageId;
  final int chunkIndex;
  final int totalChunks;
  final Uint8List data;

  const MessageChunk({
    required this.messageId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
  });

  /// Binary CBOR encoding of a MessageChunk for transmission over BLE.
  Uint8List toBytes() {
    final map = <CborValue, CborValue>{
      const CborSmallInt(0): CborString(messageId),
      const CborSmallInt(1): CborSmallInt(chunkIndex),
      const CborSmallInt(2): CborSmallInt(totalChunks),
      const CborSmallInt(3): CborBytes(data),
    };
    return Uint8List.fromList(cbor.encode(CborMap(map)));
  }

  /// Binary CBOR decoding of a MessageChunk from received BLE bytes.
  factory MessageChunk.fromBytes(Uint8List bytes) {
    final CborValue decoded = cbor.decode(bytes);
    if (decoded is! CborMap) {
      throw const FormatException('Invalid chunk CBOR: expected CborMap');
    }
    final map = decoded.map;

    final messageIdVal = map[const CborSmallInt(0)];
    final chunkIndexVal = map[const CborSmallInt(1)];
    final totalChunksVal = map[const CborSmallInt(2)];
    final dataVal = map[const CborSmallInt(3)];

    if (messageIdVal is! CborString ||
        chunkIndexVal is! CborInt ||
        totalChunksVal is! CborInt ||
        dataVal is! CborBytes) {
      throw const FormatException('Invalid chunk field types in CBOR payload');
    }

    return MessageChunk(
      messageId: messageIdVal.toString(),
      chunkIndex: chunkIndexVal.toInt(),
      totalChunks: totalChunksVal.toInt(),
      data: Uint8List.fromList(dataVal.bytes),
    );
  }

  @override
  String toString() {
    return 'MessageChunk(id: $messageId, chunk: ${chunkIndex + 1}/$totalChunks, size: ${data.length} bytes)';
  }
}
