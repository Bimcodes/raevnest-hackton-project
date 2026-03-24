import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DriverDB {
  static final DriverDB instance = DriverDB._init();
  static Database? _database;

  DriverDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('driver_wallet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE promise_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        amount_charged INTEGER NOT NULL,
        nonce INTEGER NOT NULL,
        signature TEXT NOT NULL,
        raw_payload TEXT NOT NULL,
        scanned_at INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE used_nonces (
        user_id TEXT NOT NULL,
        nonce INTEGER NOT NULL,
        PRIMARY KEY (user_id, nonce)
      )
    ''');

    await db.execute('''
      CREATE TABLE public_keys (
        user_id TEXT PRIMARY KEY,
        pem TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE blacklist (
        user_id TEXT PRIMARY KEY
      )
    ''');
    
    // Seed MVP data: the public key for STU-001 would be synced from server here, 
    // but we can just use empty or mock it when needed for MVP tests if we don't have the real one yet.
  }

  // --- Promise Notes ---

  Future<void> savePromiseNote(String userId, int amount, int nonce, String signature, String rawPayload) async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
      await txn.insert('promise_notes', {
        'user_id': userId,
        'amount_charged': amount,
        'nonce': nonce,
        'signature': signature,
        'raw_payload': rawPayload,
        'scanned_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'is_synced': 0
      });
      
      await txn.insert('used_nonces', {
        'user_id': userId,
        'nonce': nonce,
      });
    });
  }

  Future<bool> hasNonceBeenUsed(String userId, int nonce) async {
    final db = await instance.database;
    final maps = await db.query(
      'used_nonces',
      where: 'user_id = ? AND nonce = ?',
      whereArgs: [userId, nonce],
    );
    return maps.isNotEmpty;
  }
  
  Future<List<Map<String, dynamic>>> getUnsyncedNotes() async {
    final db = await instance.database;
    return await db.query('promise_notes', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getAllNotes({int limit = 100}) async {
    final db = await instance.database;
    return await db.query('promise_notes', orderBy: 'scanned_at DESC', limit: limit);
  }
  
  Future<void> markNotesSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.update('promise_notes', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // --- Blacklist & Public Keys ---

  Future<bool> isUserBlacklisted(String userId) async {
    final db = await instance.database;
    final maps = await db.query('blacklist', where: 'user_id = ?', whereArgs: [userId]);
    return maps.isNotEmpty;
  }

  Future<void> updateBlacklist(List<String> userIds) async {
    final db = await instance.database;
    final batch = db.batch();
    batch.delete('blacklist'); // clear old
    for (String id in userIds) {
      batch.insert('blacklist', {'user_id': id});
    }
    await batch.commit(noResult: true);
  }

  Future<String?> getPublicKeyPem(String userId) async {
    final db = await instance.database;
    final maps = await db.query('public_keys', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return maps.first['pem'] as String;
    }
    return null;
  }
  
  Future<void> savePublicKey(String userId, String pem) async {
    final db = await instance.database;
    await db.insert('public_keys', {'user_id': userId, 'pem': pem}, 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
