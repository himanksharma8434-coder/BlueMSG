import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/pending_message.dart';

/// Store-and-forward outbox: holds messages destined for unreachable peers
/// and retries delivery when they come back into range.
class PendingMessageRepository {
  final DatabaseHelper _dbHelper;

  /// Maximum number of delivery retries before marking as failed.
  static const int maxRetries = 10;

  /// Default TTL for pending messages: 24 hours.
  static const Duration defaultExpiry = Duration(hours: 24);

  PendingMessageRepository(this._dbHelper);

  /// Enqueue a message for store-and-forward delivery.
  Future<void> enqueue(PendingMessage pending) async {
    final db = await _dbHelper.database;
    await db.insert(
      'pending_messages',
      pending.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all pending messages for a specific recipient (e.g. when they come into range).
  Future<List<PendingMessage>> getForRecipient(String recipientId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'pending_messages',
      where: 'recipientId = ? AND expiresAt > ? AND retryCount < ?',
      whereArgs: [recipientId, now, maxRetries],
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) => PendingMessage.fromMap(row)).toList();
  }

  /// Get all pending messages that are still eligible for delivery.
  Future<List<PendingMessage>> getAllPending() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'pending_messages',
      where: 'expiresAt > ? AND retryCount < ?',
      whereArgs: [now, maxRetries],
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) => PendingMessage.fromMap(row)).toList();
  }

  /// Mark a delivery attempt (increment retryCount, update lastAttemptAt).
  Future<void> markAttempt(String messageId) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('''
      UPDATE pending_messages
      SET retryCount = retryCount + 1, lastAttemptAt = ?
      WHERE messageId = ?
    ''', [DateTime.now().millisecondsSinceEpoch, messageId]);
  }

  /// Remove a pending message (e.g. after successful delivery).
  Future<void> remove(String messageId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'pending_messages',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Purge all expired or exhausted-retry messages.
  Future<int> purgeExpired() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.delete(
      'pending_messages',
      where: 'expiresAt <= ? OR retryCount >= ?',
      whereArgs: [now, maxRetries],
    );
  }

  /// Count of pending messages in the outbox.
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_messages');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
