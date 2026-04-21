/// SpendSense - Local storage service.
/// Keeps merchant memory plus the full local transaction ledger.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/merchant_memory.dart';
import '../models/transaction.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMerchantMemoryTable(db);
    await _createTransactionsTable(db);
    await _createCustomCategoriesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionsTable(db);
      await _migrateLegacyPendingTransactions(db);
    }
    if (oldVersion < 3) {
      await _createCustomCategoriesTable(db);
    }
  }

  Future<void> _createCustomCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories (
        name TEXT PRIMARY KEY
      )
    ''');
  }

  Future<void> _createMerchantMemoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE merchant_memory (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_key TEXT    NOT NULL UNIQUE,
        category     TEXT    NOT NULL,
        type         TEXT    NOT NULL DEFAULT 'EXPENSE',
        count        INTEGER NOT NULL DEFAULT 1,
        last_seen    INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.transactionsTable} (
        id               TEXT    PRIMARY KEY,
        timestamp        INTEGER NOT NULL,
        amount           REAL    NOT NULL,
        merchant         TEXT    NOT NULL,
        category         TEXT    NOT NULL,
        confidence       TEXT    NOT NULL,
        type             TEXT    NOT NULL DEFAULT 'EXPENSE',
        note             TEXT    NOT NULL DEFAULT '',
        raw_sms          TEXT    NOT NULL DEFAULT '',
        sender           TEXT    NOT NULL DEFAULT '',
        fingerprint      TEXT    UNIQUE,
        is_logged        INTEGER NOT NULL DEFAULT 0,
        is_confirmed     INTEGER NOT NULL DEFAULT 0,
        needs_user_input INTEGER NOT NULL DEFAULT 0,
        sync_status      TEXT    NOT NULL DEFAULT 'pending',
        last_error       TEXT,
        created_at       INTEGER NOT NULL,
        updated_at       INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _migrateLegacyPendingTransactions(Database db) async {
    final exists = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*)
      FROM sqlite_master
      WHERE type = 'table' AND name = 'pending_MyTransactions'
    ''')) == 1;

    if (!exists) return;

    final legacyRows = await db.query('pending_MyTransactions');
    final batch = db.batch();

    for (final row in legacyRows) {
      final timestamp =
          row['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final isConfirmed = (row['is_confirmed'] as int? ?? 0) == 1;
      final isLogged = (row['is_logged'] as int? ?? 0) == 1;
      final confidence =
          row['confidence'] as String? ?? AppConstants.confidenceLow;

      batch.insert(
        AppConstants.transactionsTable,
        {
          'id': row['id'],
          'timestamp': timestamp,
          'amount': (row['amount'] as num?)?.toDouble() ?? 0,
          'merchant': row['merchant'] ?? 'Unknown',
          'category': row['category'] ?? 'ASK_USER',
          'confidence': confidence,
          'type': row['type'] ?? AppConstants.typeExpense,
          'note': row['note'] ?? '',
          'raw_sms': row['raw_sms'] ?? '',
          'sender': '',
          'is_logged': isLogged ? 1 : 0,
          'is_confirmed': isConfirmed ? 1 : 0,
          'needs_user_input':
              (!isConfirmed && confidence == AppConstants.confidenceLow)
                  ? 1
                  : 0,
          'sync_status':
              isLogged ? AppConstants.syncSynced : AppConstants.syncPending,
          'last_error': null,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await db.execute('DROP TABLE IF EXISTS pending_MyTransactions');
  }

  Future<MerchantMemory?> lookupMerchant(String rawMerchantName) async {
    final key = MerchantMemory.normalise(rawMerchantName);
    final db = await database;

    final results = await db.query(
      'merchant_memory',
      where: 'merchant_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return MerchantMemory.fromMap(results.first);
  }

  Future<void> saveMerchantMemory(
    String rawMerchantName,
    String category,
    String type,
  ) async {
    final key = MerchantMemory.normalise(rawMerchantName);
    final db = await database;
    final existing = await lookupMerchant(key);

    if (existing == null) {
      await db.insert(
        'merchant_memory',
        MerchantMemory(
          merchantKey: key,
          category: category,
          type: type,
          count: 1,
          lastSeen: DateTime.now(),
        ).toMap(),
      );
      return;
    }

    await db.update(
      'merchant_memory',
      {
        'category': category,
        'type': type,
        'count': existing.count + 1,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'merchant_key = ?',
      whereArgs: [key],
    );
  }

  Future<void> upsertTransaction(
    MyTransaction transaction, {
    required bool needsUserInput,
    String sender = '',
    String syncStatus = AppConstants.syncPending,
    String? lastError,
    String? fingerprint,
  }) async {
    final db = await database;
    final existing = await findTransactionById(transaction.id);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      AppConstants.transactionsTable,
      {
        'id': transaction.id,
        'timestamp': transaction.timestamp.millisecondsSinceEpoch,
        'amount': transaction.amount,
        'merchant': transaction.merchant,
        'category': transaction.category,
        'confidence': transaction.confidence,
        'type': transaction.type,
        'note': transaction.note,
        'raw_sms': transaction.rawSms,
        'sender': sender,
        'fingerprint': fingerprint,
        'is_logged':
            (syncStatus == AppConstants.syncSynced || transaction.isLogged)
                ? 1
                : 0,
        'is_confirmed': transaction.isConfirmed ? 1 : 0,
        'needs_user_input': needsUserInput ? 1 : 0,
        'sync_status': syncStatus,
        'last_error': lastError,
        'created_at': existing == null
            ? now
            : await _readCreatedAt(db, transaction.id) ?? now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MyTransaction?> findByFingerprint(String fingerprint) async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToTransaction(results.first);
  }

  Future<int?> _readCreatedAt(Database db, String transactionId) async {
    final results = await db.query(
      AppConstants.transactionsTable,
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['created_at'] as int?;
  }

  Future<List<MyTransaction>> getPending() async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'needs_user_input = 1 AND is_confirmed = 0',
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToTransaction).toList();
  }

  Future<MyTransaction?> findTransactionById(String transactionId) async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToTransaction(results.first);
  }

  Future<List<MyTransaction>> getRecentConfirmed({int limit = 30}) async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'is_confirmed = 1',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return results.map(_mapToTransaction).toList();
  }

  Future<List<MyTransaction>> getConfirmedPendingSync() async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'is_confirmed = 1 AND sync_status != ?',
      whereArgs: [AppConstants.syncSynced],
      orderBy: 'timestamp ASC',
    );

    return results.map(_mapToTransaction).toList();
  }

  Future<void> markConfirmed(
    String transactionId, {
    required String category,
    required String type,
    String? note,
  }) async {
    final db = await database;
    await db.update(
      AppConstants.transactionsTable,
      {
        'category': category,
        'type': type,
        if (note != null) 'note': note,
        'is_confirmed': 1,
        'needs_user_input': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> markSynced(String transactionId) async {
    final db = await database;
    await db.update(
      AppConstants.transactionsTable,
      {
        'is_logged': 1,
        'sync_status': AppConstants.syncSynced,
        'last_error': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> markSyncFailed(String transactionId, String error) async {
    final db = await database;
    await db.update(
      AppConstants.transactionsTable,
      {
        'is_logged': 0,
        'sync_status': AppConstants.syncFailed,
        'last_error': error,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await database;
    await db.delete(
      AppConstants.transactionsTable,
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  MyTransaction _mapToTransaction(Map<String, dynamic> map) {
    return MyTransaction(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      confidence: map['confidence'] as String,
      type: map['type'] as String,
      note: map['note'] as String,
      rawSms: map['raw_sms'] as String,
      isLogged: (map['is_logged'] as int) == 1,
      isConfirmed: (map['is_confirmed'] as int) == 1,
    );
  }

  Future<List<String>> getCustomCategories() async {
    final db = await database;
    final results = await db.query('custom_categories', orderBy: 'name ASC');
    return results.map((row) => row['name'] as String).toList();
  }

  Future<void> saveCustomCategory(String name) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// DEBUG ONLY: Wipes all transaction data and merchant memory.
  Future<void> debugClearAll() async {
    if (!kDebugMode) return;
    final db = await database;
    await db.delete(AppConstants.transactionsTable);
    await db.delete('merchant_memory');
  }
}
