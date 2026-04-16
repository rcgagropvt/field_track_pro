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
    final path = join(await getDatabasesPath(), 'offline_queue.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0
        )
      ''');
    });
  }

  static Future<void> queueInsert(String table, Map<String, dynamic> data) async {
    final database = await db;
    await database.insert('queue', {
      'table_name': table,
      'operation': 'insert',
      'payload': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    debugPrint('Queued offline: INSERT into $table');
  }

  static Future<SyncResult> sync() async {
    if (_syncing) return SyncResult(synced: 0, failed: 0);
    _syncing = true;
    int synced = 0, failed = 0;

    try {
      final database = await db;
      final rows = await database.query('queue', orderBy: 'id ASC');

      for (final row in rows) {
        try {
          final table = row['table_name'] as String;
          final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final op = row['operation'] as String;

          if (op == 'insert') {
            await SupabaseService.client.from(table).insert(payload);
          }

          await database.delete('queue', where: 'id = ?', whereArgs: [row['id']]);
          synced++;
        } catch (e) {
          final retries = (row['retry_count'] as int) + 1;
          if (retries >= 5) {
            await database.delete('queue', where: 'id = ?', whereArgs: [row['id']]);
          } else {
            await database.update('queue', {'retry_count': retries},
                where: 'id = ?', whereArgs: [row['id']]);
          }
          failed++;
        }
      }
    } finally {
      _syncing = false;
    }
    return SyncResult(synced: synced, failed: failed);
  }

  static Future<int> pendingCount() async {
    final database = await db;
    final result = await database.rawQuery('SELECT COUNT(*) as cnt FROM queue');
    return (result.first['cnt'] as int?) ?? 0;
  }
}

class SyncResult {
  final int synced;
  final int failed;
  SyncResult({required this.synced, required this.failed});
}


