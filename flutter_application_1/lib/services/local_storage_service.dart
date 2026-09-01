/// SpendSense - Local storage service.
/// Keeps merchant memory plus the full local transaction ledger.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../core/constants.dart';
import '../models/merchant_memory.dart';
import '../models/transaction.dart';
import 'secure_storage_service.dart';

class LocalStorageService {
  final String dbName;
  final bool isBackground;
  final DatabaseFactory? _factoryOverride;
  final String? _passwordOverride;

  LocalStorageService({
    this.dbName = AppConstants.dbName,
    DatabaseFactory? databaseFactory,
    this.isBackground = false,
    String? password,
  })  : _factoryOverride = databaseFactory,
        _passwordOverride = password;

  static LocalStorageService instance = LocalStorageService();

  DatabaseFactory get _dbFactory => _factoryOverride ?? databaseFactory;

  Database? _db;
  Future<Database>? _dbFuture;

  Future<Database> get database async {
    // 1. Return existing open instance if available
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    // 2. Ensure only one initialization happens at a time
    _dbFuture ??= _initDatabase();

    try {
      _db = await _dbFuture;

      // 3. Double-check if it returned an open database
      if (_db == null || !_db!.isOpen) {
        _dbFuture = null; // Reset for retry
        _db = null;
        throw Exception(
            'Database initialization returned a null or closed database');
      }

      return _db!;
    } catch (e) {
      debugPrint('SpendSense Error: Database access failed: $e');
      _dbFuture = null; // Allow retry on next access
      _db = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    if (dbName == ':memory:') {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await _dbFactory.getDatabasesPath();
      path = join(dbPath, dbName);
    }

    // Get the encryption key
    final password = _passwordOverride ??
        await SecureStorageService.instance.getDatabaseKey();

    if (password.isEmpty) {
      debugPrint(
          'SpendSense: Opening database in plaintext mode (no key provided).');
      return await _openPlaintextDatabase(path);
    }

    try {
      // 1. Try opening as encrypted
      return await _openAndKeyDatabase(path, password);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isNotADb = errorStr.contains('file is not a database') ||
          errorStr.contains('code 26');

      if (isNotADb && !isBackground) {
        debugPrint(
            'SpendSense: Detected potential plaintext database. Attempting migration...');
        try {
          final migrated = await _migrateToEncrypted(path, password);
          if (migrated) {
            debugPrint(
                'SpendSense: Migration successful. Opening new encrypted database...');
            return await _openAndKeyDatabase(path, password);
          }
        } catch (migrateError) {
          debugPrint('SpendSense Error: Migration failed: $migrateError');
        }
      }

      // If background, retry once (might be a transient lock)
      if (isBackground) {
        debugPrint('SpendSense: Background open failed. Retrying in 1s...');
        await Future.delayed(const Duration(seconds: 1));
        try {
          return await _openAndKeyDatabase(path, password);
        } catch (retryError) {
          debugPrint('SpendSense Error: Background retry failed: $retryError');
          rethrow;
        }
      }

      // Final fallback for foreground: Nuclear recovery if absolutely stuck
      debugPrint(
          'SpendSense Error: Database is corrupted or unreadable. Triggering nuclear recovery...');
      try {
        if (await _dbFactory.databaseExists(path)) {
          await _dbFactory.deleteDatabase(path);
        }
      } catch (deleteError) {
        debugPrint(
            'SpendSense Error: Failed to delete corrupted DB: $deleteError');
      }
      return await _openAndKeyDatabase(path, password);
    }
  }

  Future<Database> _openPlaintextDatabase(String path) {
    return _dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<Database> _openAndKeyDatabase(String path, String password) {
    // Note: sqflite_sqlcipher extends OpenDatabaseOptions to support password if needed,
    // but typically sqflite_sqlcipher exposes openDatabase directly.
    // To support FFI in tests, we must use _dbFactory.openDatabase.
    // Since sqflite_common_ffi doesn't support sqlcipher passwords out of the box,
    // we just open it normally if it's an FFI factory.
    return openDatabase(
      path,
      password: password,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Migrates a plaintext database to encrypted. Returns true if successful.
  Future<bool> _migrateToEncrypted(String path, String password) async {
    if (!await _dbFactory.databaseExists(path)) return false;

    Database? plaintextDb;
    try {
      // 1. Verify it's actually plaintext
      plaintextDb = await openDatabase(path, singleInstance: false);
      await plaintextDb.rawQuery('PRAGMA user_version');
      await plaintextDb.close();
      plaintextDb = null;

      // 2. Perform export to new file
      final tempPath = join(dirname(path),
          'migration_temp_${DateTime.now().millisecondsSinceEpoch}.db');

      // Re-open plaintext with no key
      plaintextDb = await openDatabase(path, singleInstance: false);

      // SQLCipher migration sequence
      await plaintextDb.execute(
          'ATTACH DATABASE ? AS encrypted KEY ?', [tempPath, password]);
      await plaintextDb.rawQuery("SELECT sqlcipher_export('encrypted')");
      await plaintextDb.execute('DETACH DATABASE encrypted');
      await plaintextDb.close();
      plaintextDb = null;

      // 3. Verify the new file exists and has content
      final tempFile = File(tempPath);
      if (await tempFile.exists() && await tempFile.length() > 0) {
        final originalFile = File(path);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }
        await tempFile.rename(path);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SpendSense Error: Migration logic error: $e');
      if (plaintextDb != null && plaintextDb.isOpen) {
        await plaintextDb.close();
      }
      return false;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMerchantMemoryTable(db);
    await _createTransactionsTable(db);
    await _createCustomCategoriesTable(db);
    await _createCategoryMetadataTable(db);
    await _createGoalsTables(db);
    await _createClassificationTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionsTable(db);
      await _migrateLegacyPendingTransactions(db);
    }
    if (oldVersion < 3) {
      await _createCustomCategoriesTable(db);
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE merchant_memory ADD COLUMN is_dynamic INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE custom_categories ADD COLUMN emoji TEXT NOT NULL DEFAULT "🏷️"');
    }
    if (oldVersion < 6) {
      await _createCategoryMetadataTable(db);
    }
    if (oldVersion < 7) {
      await _createGoalsTables(db);
    }
    if (oldVersion < 8) {
      await _createClassificationTable(db);
    }
  }

  Future<void> _createClassificationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_classifications (
        merchant_or_category TEXT PRIMARY KEY,
        nature TEXT NOT NULL CHECK(nature IN ('recurring','sometime')),
        expected_amount REAL,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createGoalsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_goals (
        id INTEGER PRIMARY KEY DEFAULT 1,
        monthly_total_limit REAL NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL UNIQUE,
        monthly_limit REAL NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL
      )
    ''');
    // Seed default row so existing users never read null
    await db.execute(
        "INSERT OR IGNORE INTO user_goals VALUES (1, 0, datetime('now'))");
  }

  Future<void> _createCategoryMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_metadata (
        category_name TEXT PRIMARY KEY,
        description   TEXT NOT NULL,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCustomCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories (
        name  TEXT PRIMARY KEY,
        emoji TEXT NOT NULL DEFAULT '🏷️'
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
        is_dynamic   INTEGER NOT NULL DEFAULT 0,
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
    String type, {
    bool isDynamic = false,
  }) async {
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
          isDynamic: isDynamic,
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
        'is_dynamic': isDynamic ? 1 : 0,
        'count': existing.count + 1,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'merchant_key = ?',
      whereArgs: [key],
    );
  }

  Future<MyTransaction?> findTransactionById(String id) async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return _mapToTransaction(results.first);
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
      where: 'needs_user_input = 1',
      orderBy: 'timestamp DESC',
    );

    return results.map(_mapToTransaction).toList();
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

  Future<List<MyTransaction>> getTransactionsByCategory(String category) async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'category = ? AND is_confirmed = 1',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
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
    return MyTransaction.fromMap(map);
  }

  Future<List<MyTransaction>> getUnsynced() async {
    final db = await database;
    final results = await db.query(
      AppConstants.transactionsTable,
      where: 'sync_status != ?',
      whereArgs: [AppConstants.syncSynced],
      orderBy: 'timestamp DESC',
    );
    return results.map(_mapToTransaction).toList();
  }

  Future<void> saveCategoryMetadata(
      String categoryName, String description) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'category_metadata',
      {
        'category_name': categoryName,
        'description': description,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCategoryDescription(String categoryName) async {
    final db = await database;
    final results = await db.query(
      'category_metadata',
      columns: ['description'],
      where: 'category_name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['description'] as String?;
  }

  Future<Map<String, String>> getAllCategoryDescriptions() async {
    final db = await database;
    final results = await db.query('category_metadata');
    return {
      for (final row in results)
        row['category_name'] as String: row['description'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> getCustomCategories() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT c.name, c.emoji, m.description
      FROM custom_categories c
      LEFT JOIN category_metadata m ON c.name = m.category_name
      ORDER BY c.name ASC
    ''');
    return results;
  }

  Future<void> saveCustomCategory(String name, {String emoji = '🏷️'}) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      {'name': name, 'emoji': emoji},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameCategory(String oldName, String newName,
      {String? newEmoji}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        AppConstants.transactionsTable,
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );

      await txn.update(
        'merchant_memory',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );

      final results = await txn.query(
        'custom_categories',
        where: 'name = ?',
        whereArgs: [oldName],
      );

      final emoji = newEmoji ??
          (results.isNotEmpty ? results.first['emoji'] as String : '🏷️');

      await txn.delete(
        'custom_categories',
        where: 'name = ?',
        whereArgs: [oldName],
      );

      await txn.insert(
        'custom_categories',
        {'name': newName, 'emoji': emoji},
      );

      // Rename metadata if it exists
      await txn.update(
        'category_metadata',
        {'category_name': newName},
        where: 'category_name = ?',
        whereArgs: [oldName],
      );
    });
  }

  Future<void> deleteCategory(String name) async {
    final db = await database;

    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${AppConstants.transactionsTable} WHERE category = ?',
          [name],
        )) ??
        0;

    if (count > 0) {
      throw Exception(
          'Cannot delete category "$name" because it has $count transactions. Reassign them first.');
    }

    await db.delete(
      'custom_categories',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> reassignAndExcludeCategory(
      String oldName, String targetName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        AppConstants.transactionsTable,
        {'category': targetName},
        where: 'category = ?',
        whereArgs: [oldName],
      );

      await txn.update(
        'merchant_memory',
        {'category': targetName},
        where: 'category = ?',
        whereArgs: [oldName],
      );

      await txn.delete(
        'custom_categories',
        where: 'name = ?',
        whereArgs: [oldName],
      );
    });
  }

  /// DEBUG ONLY: Wipes all transaction data and merchant memory.
  Future<void> debugClearAll() async {
    if (!kDebugMode) return;
    final db = await database;
    await db.delete(AppConstants.transactionsTable);
    await db.delete('merchant_memory');
  }
}
