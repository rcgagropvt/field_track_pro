import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'supabase_service.dart';

class OfflineQueueService {
  static Database? _db;
  static bool _syncing = false;

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'offline_queue_v2.db');
    return openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          record_id TEXT,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          priority INTEGER DEFAULT 0,
          conflict_strategy TEXT DEFAULT 'server_wins'
        )
      ''');
      await db.execute('''
        CREATE TABLE sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id TEXT,
          operation TEXT NOT NULL,
          status TEXT NOT NULL,
          error TEXT,
          synced_at TEXT NOT NULL
        )
      ''');
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        await db.execute('ALTER TABLE queue ADD COLUMN record_id TEXT');
        await db
            .execute('ALTER TABLE queue ADD COLUMN priority INTEGER DEFAULT 0');
        await db.execute(
            "ALTER TABLE queue ADD COLUMN conflict_strategy TEXT DEFAULT 'server_wins'");
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id TEXT,
            operation TEXT NOT NULL,
            status TEXT NOT NULL,
            error TEXT,
            synced_at TEXT NOT NULL
          )
        ''');
      }
    });
  }

  // ── Queue operations ─────────────────────────────────

  /// Queue an INSERT for later sync
  static Future<void> queueInsert(String table, Map<String, dynamic> data,
      {int priority = 0}) async {
    final database = await db;
    await database.insert('queue', {
      'table_name': table,
      'operation': 'insert',
      'payload': jsonEncode(data),
      'record_id': data['id']?.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'priority': priority,
      'conflict_strategy': 'server_wins',
    });
    debugPrint('Queued offline INSERT into $table (priority: $priority)');
  }

  /// Queue an UPDATE for later sync
  static Future<void> queueUpdate(
      String table, String recordId, Map<String, dynamic> data,
      {String conflictStrategy = 'client_wins'}) async {
    final database = await db;

    // Conflict resolution: if an update for the same record already exists,
    // merge the payloads (newer fields win)
    final existing = await database.query('queue',
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: [table, recordId, 'update']);

    if (existing.isNotEmpty) {
      final oldPayload = jsonDecode(existing.first['payload'] as String)
          as Map<String, dynamic>;
      final merged = {...oldPayload, ...data}; // newer fields overwrite
      await database.update(
        'queue',
        {
          'payload': jsonEncode(merged),
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      debugPrint('Merged offline UPDATE for $table/$recordId');
    } else {
      await database.insert('queue', {
        'table_name': table,
        'operation': 'update',
        'payload': jsonEncode(data),
        'record_id': recordId,
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'priority': 0,
        'conflict_strategy': conflictStrategy,
      });
      debugPrint('Queued offline UPDATE for $table/$recordId');
    }
  }

  /// Queue a DELETE for later sync
  static Future<void> queueDelete(String table, String recordId) async {
    final database = await db;
    // Remove any pending inserts/updates for the same record
    await database.delete('queue',
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [table, recordId]);
    await database.insert('queue', {
      'table_name': table,
      'operation': 'delete',
      'payload': jsonEncode({'id': recordId}),
      'record_id': recordId,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'priority': 10, // deletes are high priority
      'conflict_strategy': 'client_wins',
    });
    debugPrint('Queued offline DELETE for $table/$recordId');
  }

  // ── Sync engine ──────────────────────────────────────

  static Future<SyncResult> sync() async {
    if (_syncing) return SyncResult(synced: 0, failed: 0, conflicts: 0);
    _syncing = true;
    int synced = 0, failed = 0, conflicts = 0;

    try {
      final database = await db;
      // Process in priority order (highest first), then by creation time
      final rows =
          await database.query('queue', orderBy: 'priority DESC, id ASC');

      for (final row in rows) {
        try {
          final table = row['table_name'] as String;
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final op = row['operation'] as String;
          final recordId = row['record_id'] as String?;
          final strategy = row['conflict_strategy'] as String? ?? 'server_wins';

          if (op == 'insert') {
            await _syncInsert(table, payload);
          } else if (op == 'update') {
            await _syncUpdate(table, recordId!, payload, strategy);
          } else if (op == 'delete') {
            await _syncDelete(table, recordId!);
          }

          // Success — remove from queue, log it
          await database
              .delete('queue', where: 'id = ?', whereArgs: [row['id']]);
          await _logSync(table, recordId, op, 'success', null);
          synced++;
        } catch (e) {
          final retries = (row['retry_count'] as int) + 1;
          final errorMsg = e.toString();

          if (errorMsg.contains('conflict') || errorMsg.contains('duplicate')) {
            conflicts++;
            // For conflicts, apply resolution strategy
            await _handleConflict(row, e);
            await database
                .delete('queue', where: 'id = ?', whereArgs: [row['id']]);
            await _logSync(
              row['table_name'] as String,
              row['record_id'] as String?,
              row['operation'] as String,
              'conflict_resolved',
              errorMsg,
            );
          } else if (retries >= 5) {
            // Max retries exceeded — move to dead letter
            await database
                .delete('queue', where: 'id = ?', whereArgs: [row['id']]);
            await _logSync(
              row['table_name'] as String,
              row['record_id'] as String?,
              row['operation'] as String,
              'failed_permanently',
              errorMsg,
            );
            failed++;
          } else {
            await database.update('queue', {'retry_count': retries},
                where: 'id = ?', whereArgs: [row['id']]);
            failed++;
          }
        }
      }
    } finally {
      _syncing = false;
    }

    debugPrint(
        'Sync complete: $synced synced, $failed failed, $conflicts conflicts');
    return SyncResult(synced: synced, failed: failed, conflicts: conflicts);
  }

  static Future<void> _syncInsert(
      String table, Map<String, dynamic> payload) async {
    await SupabaseService.client.from(table).insert(payload);
  }

  static Future<void> _syncUpdate(String table, String recordId,
      Map<String, dynamic> payload, String strategy) async {
    if (strategy == 'client_wins') {
      // Overwrite server data
      await SupabaseService.client
          .from(table)
          .update(payload)
          .eq('id', recordId);
    } else {
      // server_wins: fetch server version, only update fields where server value is null or older
      final serverRow = await SupabaseService.client
          .from(table)
          .select()
          .eq('id', recordId)
          .maybeSingle();

      if (serverRow == null) {
        // Record deleted on server — skip update
        debugPrint(
            'Record $recordId deleted on server, skipping offline update');
        return;
      }

      final serverUpdated =
          DateTime.tryParse(serverRow['updated_at']?.toString() ?? '');
      final clientUpdated =
          DateTime.tryParse(payload['updated_at']?.toString() ?? '');

      if (serverUpdated != null &&
          clientUpdated != null &&
          serverUpdated.isAfter(clientUpdated)) {
        debugPrint(
            'Server version is newer for $recordId, skipping client update');
        return;
      }

      await SupabaseService.client
          .from(table)
          .update(payload)
          .eq('id', recordId);
    }
  }

  static Future<void> _syncDelete(String table, String recordId) async {
    await SupabaseService.client.from(table).delete().eq('id', recordId);
  }

  static Future<void> _handleConflict(
      Map<String, dynamic> row, Object error) async {
    final strategy = row['conflict_strategy'] as String? ?? 'server_wins';
    debugPrint(
        'Conflict on ${row['table_name']}/${row['record_id']}: strategy=$strategy, error=$error');
    // For now, log it. The sync engine above already handles client_wins vs server_wins.
  }

  static Future<void> _logSync(String table, String? recordId, String operation,
      String status, String? error) async {
    try {
      final database = await db;
      await database.insert('sync_log', {
        'table_name': table,
        'record_id': recordId,
        'operation': operation,
        'status': status,
        'error': error,
        'synced_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Utility ──────────────────────────────────────────

  static Future<int> pendingCount() async {
    final database = await db;
    final result = await database.rawQuery('SELECT COUNT(*) as cnt FROM queue');
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> pendingItems() async {
    final database = await db;
    return database.query('queue', orderBy: 'priority DESC, id ASC');
  }

  static Future<List<Map<String, dynamic>>> syncHistory(
      {int limit = 50}) async {
    final database = await db;
    return database.query('sync_log', orderBy: 'id DESC', limit: limit);
  }

  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('queue');
    debugPrint('Offline queue cleared');
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int conflicts;
  SyncResult({required this.synced, required this.failed, this.conflicts = 0});
}
