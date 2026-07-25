import 'package:flutter_test/flutter_test.dart';
import 'package:bitmsg/protocol/cache/dedup_cache.dart';

void main() {
  group('DedupCache Unit Tests', () {
    test('deduplicates added message IDs', () {
      final cache = DedupCache();
      const msgId = 'msg-1001';

      expect(cache.hasSeen(msgId), isFalse);
      cache.add(msgId);
      expect(cache.hasSeen(msgId), isTrue);
      // Repeated checks maintain seen state
      expect(cache.hasSeen(msgId), isTrue);
    });

    test('enforces maxCapacity with LRU eviction', () {
      final cache = DedupCache(maxCapacity: 3);

      cache.add('msg-1');
      cache.add('msg-2');
      cache.add('msg-3');

      expect(cache.length, equals(3));
      expect(cache.hasSeen('msg-1'), isTrue);

      // Accessing msg-1 moves it to most recently used.
      // Now adding msg-4 should evict the oldest unaccessed item ('msg-2').
      cache.add('msg-4');

      expect(cache.length, equals(3));
      expect(cache.hasSeen('msg-2'), isFalse); // Evicted!
      expect(cache.hasSeen('msg-1'), isTrue);
      expect(cache.hasSeen('msg-3'), isTrue);
      expect(cache.hasSeen('msg-4'), isTrue);
    });

    test('evicts entries older than time window', () async {
      final cache = DedupCache(
        expiryWindow: const Duration(milliseconds: 100),
      );

      cache.add('fast-expire-id');
      expect(cache.hasSeen('fast-expire-id'), isTrue);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(cache.hasSeen('fast-expire-id'), isFalse);
    });
  });
}
