import 'dart:collection';

class _CacheEntry {
  final DateTime timestamp;
  _CacheEntry(this.timestamp);
}

/// LRU & Time-windowed deduplication cache for message IDs.
class DedupCache {
  final int maxCapacity;
  final Duration expiryWindow;

  /// Ordered map for LRU tracking: key = messageId, value = _CacheEntry
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap<String, _CacheEntry>();

  DedupCache({
    this.maxCapacity = 1000,
    this.expiryWindow = const Duration(minutes: 15),
  });

  /// Checks if [messageId] is already seen (and not expired).
  bool hasSeen(String messageId) {
    _evictExpired();

    final entry = _cache.remove(messageId);
    if (entry == null) {
      return false;
    }

    // Check if expired
    if (DateTime.now().difference(entry.timestamp) > expiryWindow) {
      return false; // Evicted
    }

    // Re-insert at end of LRU
    _cache[messageId] = entry;
    return true;
  }

  /// Adds [messageId] to the cache.
  void add(String messageId) {
    _evictExpired();

    _cache.remove(messageId);
    _cache[messageId] = _CacheEntry(DateTime.now());

    // Enforce max capacity by removing oldest (first item in LinkedHashMap)
    while (_cache.length > maxCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Returns current cache size (unexpired items count after eviction).
  int get length {
    _evictExpired();
    return _cache.length;
  }

  /// Removes all expired entries.
  void _evictExpired() {
    final now = DateTime.now();
    _cache.removeWhere((id, entry) => now.difference(entry.timestamp) > expiryWindow);
  }

  /// Clears cache.
  void clear() {
    _cache.clear();
  }
}
