import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/peer.dart';

/// Repository for known peers / contacts.
class PeerRepository {
  final DatabaseHelper _dbHelper;

  PeerRepository(this._dbHelper);

  /// Upsert a peer — insert if new, update lastSeen / keys if existing.
  Future<void> upsertPeer(Peer peer) async {
    final db = await _dbHelper.database;
    await db.insert(
      'peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a peer by deviceId.
  Future<Peer?> getPeerById(String deviceId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'peers',
      where: 'deviceId = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Peer.fromMap(rows.first);
  }

  /// Get all known peers, ordered by lastSeen descending.
  Future<List<Peer>> getAllPeers() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'peers',
      orderBy: 'lastSeen DESC',
    );
    return rows.map((row) => Peer.fromMap(row)).toList();
  }

  /// Update a peer's nickname.
  Future<void> updateNickname(String deviceId, String nickname) async {
    final db = await _dbHelper.database;
    await db.update(
      'peers',
      {'nickname': nickname},
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
  }

  /// Update a peer's lastSeen timestamp.
  Future<void> updateLastSeen(String deviceId, int timestamp) async {
    final db = await _dbHelper.database;
    await db.update(
      'peers',
      {'lastSeen': timestamp},
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
  }

  /// Delete a peer.
  Future<int> deletePeer(String deviceId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'peers',
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
  }
}
