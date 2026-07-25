import 'dart:typed_data';
import 'chunk_model.dart';

class _ChunkBuffer {
  final int totalChunks;
  final Map<int, Uint8List> receivedChunks = {};
  final DateTime createdAt;

  _ChunkBuffer(this.totalChunks) : createdAt = DateTime.now();

  bool get isComplete => receivedChunks.length == totalChunks;

  Uint8List? reassemble() {
    if (!isComplete) return null;
    final builder = BytesBuilder();
    for (int i = 0; i < totalChunks; i++) {
      final chunkData = receivedChunks[i];
      if (chunkData == null) return null; // Missing chunk index
      builder.add(chunkData);
    }
    return builder.toBytes();
  }
}

/// Buffers incoming chunks and reassembles complete payload bytes.
class Reassembler {
  final Duration timeout;
  final Map<String, _ChunkBuffer> _buffers = {};

  Reassembler({this.timeout = const Duration(minutes: 2)});

  /// Adds a chunk to the buffer.
  /// Returns complete reassembled [Uint8List] if all chunks for this messageId are received,
  /// or `null` if still waiting for more chunks.
  Uint8List? addChunk(MessageChunk chunk) {
    _cleanupStaleBuffers();

    var buffer = _buffers[chunk.messageId];
    if (buffer == null) {
      buffer = _ChunkBuffer(chunk.totalChunks);
      _buffers[chunk.messageId] = buffer;
    }

    buffer.receivedChunks[chunk.chunkIndex] = chunk.data;

    if (buffer.isComplete) {
      final assembled = buffer.reassemble();
      _buffers.remove(chunk.messageId);
      return assembled;
    }

    return null;
  }

  /// Removes chunk buffers that have timed out without receiving all chunks.
  void _cleanupStaleBuffers() {
    final now = DateTime.now();
    _buffers.removeWhere((id, buffer) => now.difference(buffer.createdAt) > timeout);
  }

  /// Clear all buffers (e.g. for testing).
  void clear() {
    _buffers.clear();
  }
}
