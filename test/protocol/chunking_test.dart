import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitmsg/protocol/transport/chunk_model.dart';
import 'package:bitmsg/protocol/transport/chunker.dart';
import 'package:bitmsg/protocol/transport/reassembler.dart';

void main() {
  group('Chunking & Reassembly Tests', () {
    test('MessageChunk CBOR serialization round-trip', () {
      final chunk = MessageChunk(
        messageId: 'msg-uuid-999',
        chunkIndex: 2,
        totalChunks: 5,
        data: Uint8List.fromList([10, 20, 30, 40, 50]),
      );

      final bytes = chunk.toBytes();
      expect(bytes, isNotEmpty);

      final decoded = MessageChunk.fromBytes(bytes);
      expect(decoded.messageId, equals('msg-uuid-999'));
      expect(decoded.chunkIndex, equals(2));
      expect(decoded.totalChunks, equals(5));
      expect(decoded.data, equals(chunk.data));
    });

    test('Chunker splits large byte array into correct number of chunks', () {
      final largePayload = Uint8List.fromList(List.generate(500, (i) => i % 256));
      const messageId = 'large-message-id';

      final chunks = Chunker.chunkEnvelope(
        messageId: messageId,
        payloadBytes: largePayload,
        maxChunkPayloadSize: 150,
      );

      expect(chunks.length, equals(4)); // ceil(500 / 150) = 4
      expect(chunks[0].chunkIndex, equals(0));
      expect(chunks[0].totalChunks, equals(4));
      expect(chunks[0].data.length, equals(150));

      expect(chunks[3].chunkIndex, equals(3));
      expect(chunks[3].totalChunks, equals(4));
      expect(chunks[3].data.length, equals(50)); // 500 - 450 = 50
    });

    test('Reassembler rebuilds full payload in-order', () {
      final originalData = Uint8List.fromList(List.generate(400, (i) => (i * 3) % 256));
      const messageId = 'rebuild-in-order-id';

      final chunks = Chunker.chunkEnvelope(
        messageId: messageId,
        payloadBytes: originalData,
        maxChunkPayloadSize: 100,
      );

      final reassembler = Reassembler();

      Uint8List? result;
      for (int i = 0; i < chunks.length; i++) {
        final assembled = reassembler.addChunk(chunks[i]);
        if (i == chunks.length - 1) {
          result = assembled;
        } else {
          expect(assembled, isNull);
        }
      }

      expect(result, isNotNull);
      expect(result, equals(originalData));
    });

    test('Reassembler rebuilds full payload out-of-order', () {
      final originalData = Uint8List.fromList(List.generate(350, (i) => (i + 7) % 256));
      const messageId = 'rebuild-out-of-order-id';

      final chunks = Chunker.chunkEnvelope(
        messageId: messageId,
        payloadBytes: originalData,
        maxChunkPayloadSize: 100,
      );

      expect(chunks.length, equals(4));

      final reassembler = Reassembler();

      // Add out of order: chunk 2, chunk 0, chunk 3, chunk 1
      expect(reassembler.addChunk(chunks[2]), isNull);
      expect(reassembler.addChunk(chunks[0]), isNull);
      expect(reassembler.addChunk(chunks[3]), isNull);

      final assembled = reassembler.addChunk(chunks[1]);
      expect(assembled, isNotNull);
      expect(assembled, equals(originalData));
    });

    test('Reassembler handles multiple concurrent message streams', () {
      final dataA = Uint8List.fromList([1, 2, 3, 4, 5]);
      final dataB = Uint8List.fromList([10, 20, 30, 40, 50, 60]);

      final chunksA = Chunker.chunkEnvelope(messageId: 'stream-A', payloadBytes: dataA, maxChunkPayloadSize: 2);
      final chunksB = Chunker.chunkEnvelope(messageId: 'stream-B', payloadBytes: dataB, maxChunkPayloadSize: 2);

      final reassembler = Reassembler();

      reassembler.addChunk(chunksA[0]);
      reassembler.addChunk(chunksB[0]);
      reassembler.addChunk(chunksA[1]);

      final resultB1 = reassembler.addChunk(chunksB[1]);
      expect(resultB1, isNull);

      final resultAFinal = reassembler.addChunk(chunksA[2]);
      expect(resultAFinal, equals(dataA));

      final resultB2 = reassembler.addChunk(chunksB[2]);
      expect(resultB2, equals(dataB));
    });
  });
}
