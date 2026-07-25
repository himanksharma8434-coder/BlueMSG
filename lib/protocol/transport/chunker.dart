import 'dart:typed_data';
import 'chunk_model.dart';

/// Splits raw envelope bytes into MessageChunks for BLE transport.
class Chunker {
  /// Splits [payloadBytes] into a list of [MessageChunk]s.
  /// [maxChunkPayloadSize] determines the max size of raw data in each chunk.
  static List<MessageChunk> chunkEnvelope({
    required String messageId,
    required Uint8List payloadBytes,
    int maxChunkPayloadSize = 90,
  }) {
    if (payloadBytes.isEmpty) {
      return [
        MessageChunk(
          messageId: messageId,
          chunkIndex: 0,
          totalChunks: 1,
          data: Uint8List(0),
        )
      ];
    }

    final totalChunks = (payloadBytes.length / maxChunkPayloadSize).ceil();
    final chunks = <MessageChunk>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * maxChunkPayloadSize;
      final end = (start + maxChunkPayloadSize < payloadBytes.length)
          ? start + maxChunkPayloadSize
          : payloadBytes.length;

      final chunkData = payloadBytes.sublist(start, end);

      chunks.add(
        MessageChunk(
          messageId: messageId,
          chunkIndex: i,
          totalChunks: totalChunks,
          data: Uint8List.fromList(chunkData),
        ),
      );
    }

    return chunks;
  }
}
