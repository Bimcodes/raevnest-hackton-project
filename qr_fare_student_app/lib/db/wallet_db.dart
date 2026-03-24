import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class WalletDB {
  static final WalletDB instance = WalletDB._init();
  static Database? _database;

  WalletDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wallet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        balance INTEGER NOT NULL,
        locked_amount INTEGER NOT NULL,
        nonce INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE refund_claims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nonce INTEGER NOT NULL,
        actual_fare INTEGER NOT NULL,
        stop_id TEXT NOT NULL,
        gps_proof_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nonce INTEGER NOT NULL,
        pickup TEXT NOT NULL,
        destination TEXT NOT NULL,
        fare_kobo INTEGER NOT NULL,
        people_count INTEGER NOT NULL DEFAULT 1,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Initialize the single wallet row
    await db.insert('wallet', {
      'balance': 0,
      'locked_amount': 0,
      'nonce': 0,
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS trip_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nonce INTEGER NOT NULL,
          pickup TEXT NOT NULL,
          destination TEXT NOT NULL,
          fare_kobo INTEGER NOT NULL,
          people_count INTEGER NOT NULL DEFAULT 1,
          timestamp INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE trip_history ADD COLUMN people_count INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future<Map<String, dynamic>> getWalletState() async {
    final db = await instance.database;
    final maps = await db.query('wallet', limit: 1);
    return maps.first;
  }

  Future<void> updateBalance(int newBalance) async {
    final db = await instance.database;
    await db.update('wallet', {'balance': newBalance});
  }

  Future<int> getNextNonce() async {
    final db = await instance.database;
    final state = await getWalletState();
    final newNonce = (state['nonce'] as int) + 1;
    await db.update('wallet', {'nonce': newNonce});
    return newNonce;
  }

  Future<void> deductAndLock(int amount) async {
    final db = await instance.database;
    final state = await getWalletState();
    final currentBalance = state['balance'] as int;
    final currentLocked = state['locked_amount'] as int;

    if (currentBalance < amount) {
      throw Exception('Insufficient balance');
    }

    await db.update('wallet', {
      'balance': currentBalance - amount,
      'locked_amount': currentLocked + amount,
    });
  }

  Future<void> unlock(int refundAmount) async {
    final db = await instance.database;
    final state = await getWalletState();
    final currentBalance = state['balance'] as int;
    final currentLocked = state['locked_amount'] as int;

    // We assume the caller knows how much was originally locked for the trip.
    // For MVP, we just reset locked to 0 and add refund to balance.
    await db.update('wallet', {
      'balance': currentBalance + refundAmount,
      'locked_amount': 0, // trip ended
    });
  }

  Future<void> addRefundClaim(int nonce, int actualFare, String stopId, String proof) async {
    final db = await instance.database;
    await db.insert('refund_claims', {
      'nonce': nonce,
      'actual_fare': actualFare,
      'stop_id': stopId,
      'gps_proof_json': proof,
    });
  }
  
  Future<List<Map<String, dynamic>>> getUnsyncedRefundClaims() async {
    final db = await instance.database;
    return await db.query('refund_claims');
  }
  
  Future<void> clearSyncedRefundClaims(List<int> nonces) async {
    final db = await instance.database;
    for (var n in nonces) {
      await db.delete('refund_claims', where: 'nonce = ?', whereArgs: [n]);
    }
  }

  Future<void> addTripHistory({
    required int nonce,
    required String pickup,
    required String destination,
    required int fareKobo,
    int peopleCount = 1,
  }) async {
    final db = await instance.database;
    await db.insert('trip_history', {
      'nonce': nonce,
      'pickup': pickup,
      'destination': destination,
      'fare_kobo': fareKobo,
      'people_count': peopleCount,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getTripHistory() async {
    final db = await instance.database;
    return await db.query('trip_history', orderBy: 'timestamp DESC');
  }
}
