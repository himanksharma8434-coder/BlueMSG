import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Singleton database helper — manages schema creation and migrations.
class DatabaseHelper {
  static const String _dbName = 'bitmsg.db';
  static const int _dbVersion = 1;

  Database? _database;
  final DatabaseFactory? _factory; // Allows injection for testing
  final String? _dbPath; // Allows overriding path (e.g. inMemoryDatabasePath for tests)

  DatabaseHelper({DatabaseFactory? factory, String? dbPath})
      : _factory = factory,
        _dbPath = dbPath;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = _factory ?? databaseFactory;
    final String path;
    if (_dbPath != null) {
      path = _dbPath;
    } else {
      final dbDir = await factory.getDatabasesPath();
      path = p.join(dbDir, _dbName);
    }

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        recipientId TEXT,
        body TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        direction INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_messages_conversation ON messages (conversationId, timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_status ON messages (status)',
    );

    // Peers / contacts table
    await db.execute('''
      CREATE TABLE peers (
        deviceId TEXT PRIMARY KEY,
        publicKey TEXT NOT NULL,
        encryptionKey TEXT,
        nickname TEXT,
        lastSeen INTEGER
      )
    ''');

    // Store-and-forward outbox
    await db.execute('''
      CREATE TABLE pending_messages (
        messageId TEXT PRIMARY KEY,
        recipientId TEXT NOT NULL,
        envelopeBytes BLOB NOT NULL,
        createdAt INTEGER NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastAttemptAt INTEGER,
        expiresAt INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_pending_recipient ON pending_messages (recipientId)',
    );
    await db.execute(
      'CREATE INDEX idx_pending_expires ON pending_messages (expiresAt)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
