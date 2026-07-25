import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/stored_message.dart';

/// Repository for chat messages — insert, query history, update status.
class MessageRepository {
  final DatabaseHelper _dbHelper;

  MessageRepository(this._dbHelper);

  /// Insert a new message into local storage.
  Future<void> insertMessage(StoredMessage message) async {
    final db = await _dbHelper.database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // Skip duplicates
    );
  }

  /// Update the delivery status of a message.
  Future<void> updateStatus(String messageId, DeliveryStatus status) async {
    final db = await _dbHelper.database;
    await db.update(
      'messages',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Get chat history for a conversation, ordered newest-first.
  Future<List<StoredMessage>> getConversationHistory(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) => StoredMessage.fromMap(row)).toList();
  }

  /// Get a single message by ID.
  Future<StoredMessage?> getMessageById(String messageId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoredMessage.fromMap(rows.first);
  }

  /// Get all distinct conversation IDs with the latest message and timestamp.
  Future<List<Map<String, dynamic>>> getConversationList() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT m.conversationId, m.body AS lastMessage, m.timestamp AS lastTimestamp,
             m.senderId, m.direction,
             p.nickname AS peerNickname
      FROM messages m
      LEFT JOIN peers p ON m.conversationId = p.deviceId
      WHERE m.timestamp = (
        SELECT MAX(m2.timestamp) FROM messages m2 WHERE m2.conversationId = m.conversationId
      )
      ORDER BY m.timestamp DESC
    ''');
  }

  /// Delete all messages for a conversation.
  Future<int> deleteConversation(String conversationId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
  }

  /// Count of messages with a given status.
  Future<int> countByStatus(DeliveryStatus status) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE status = ?',
      [status.index],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
