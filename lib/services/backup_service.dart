// lib/services/backup_service.dart
//
// Updates:
// - Friendlier validation errors (FormatException messages)
// - Still ignores unknown fields on restore (future-proof)

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database/app_database.dart'; // keep your path

class BackupService {
  BackupService._();

  static const String appId = 'story_stalker';
  static const int backupVersion = 1;

  static Future<String?> exportJsonBackup({
    String suggestedFileName = 'story_stalker_backup.json',
  }) async {
    // Your project: you said this line is like: await AppDatabase.instance.db;
    final db = await AppDatabase.instance.db;

    final userVersionRow = await db.rawQuery('PRAGMA user_version;');
    final schemaVersion = (userVersionRow.isNotEmpty)
        ? (userVersionRow.first.values.first as int? ?? 0)
        : 0;

    final tables = await _getUserTables(db);

    final data = <String, List<Map<String, Object?>>> {};
    for (final table in tables) {
      final rows = await db.query(table);
      data[table] = rows;
    }

    final payload = <String, Object?>{
      'app': appId,
      'backupVersion': backupVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
      'data': data,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export backup',
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (path == null) return null;

    final file = File(path);
    await file.writeAsString(jsonString, flush: true);

    return path;
  }

  static Future<String?> restoreJsonBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Restore backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    final file = File(path);
    final jsonString = await file.readAsString();

    Object decodedAny;
    try {
      decodedAny = jsonDecode(jsonString);
    } catch (_) {
      throw const FormatException('That file isn’t valid JSON.');
    }

    if (decodedAny is! Map<String, Object?>) {
      throw const FormatException('Backup file format is invalid (root object).');
    }

    final decoded = decodedAny;

    final app = decoded['app'];
    if (app is! String || app.trim().isEmpty) {
      throw const FormatException('Backup file is missing the "app" field.');
    }
    if (app != appId) {
      throw FormatException('That backup is for "$app", not Story Stalker.');
    }

    final backupVer = decoded['backupVersion'];
    if (backupVer is! int) {
      throw const FormatException('Backup file is missing "backupVersion".');
    }
    if (backupVer != backupVersion) {
      throw FormatException(
        'Unsupported backup version ($backupVer).',
      );
    }

    final dataObj = decoded['data'];
    if (dataObj is! Map<String, Object?>) {
      throw const FormatException('Backup file is missing "data".');
    }

    final backupData = <String, List<Map<String, Object?>>>{};
    for (final entry in dataObj.entries) {
      final table = entry.key;
      final rowsAny = entry.value;

      if (rowsAny is! List) continue;

      final rows = <Map<String, Object?>>[];
      for (final r in rowsAny) {
        if (r is Map) {
          rows.add(r.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      backupData[table] = rows;
    }

    final db = await AppDatabase.instance.db;

    final currentTables = await _getUserTables(db);

    final tableColumns = <String, Set<String>>{};
    for (final t in currentTables) {
      tableColumns[t] = await _getColumnsForTable(db, t);
    }

    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF;');

      for (final table in currentTables.reversed) {
        await txn.delete(table);
      }

      final tablesToRestore = backupData.keys
          .where(currentTables.contains)
          .toList()
        ..sort();

      for (final table in tablesToRestore) {
        final cols = tableColumns[table] ?? const <String>{};
        final rows = backupData[table] ?? const [];

        for (final row in rows) {
          final filtered = <String, Object?>{};
          for (final e in row.entries) {
            if (cols.contains(e.key)) {
              filtered[e.key] = _normalizeJsonValue(e.value);
            }
          }
          if (filtered.isEmpty) continue;

          await txn.insert(
            table,
            filtered,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await txn.execute('PRAGMA foreign_keys = ON;');
    });

    return path;
  }

  static Future<List<String>> _getUserTables(Database db) async {
    final rows = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type='table'
        AND name NOT LIKE 'sqlite_%'
      ORDER BY name;
    ''');

    final tables = <String>[];
    for (final r in rows) {
      final name = r['name'];
      if (name is String && name.trim().isNotEmpty) {
        tables.add(name);
      }
    }
    return tables;
  }

  static Future<Set<String>> _getColumnsForTable(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table);');
    final cols = <String>{};
    for (final r in rows) {
      final name = r['name'];
      if (name is String) cols.add(name);
    }
    return cols;
  }

  static Object? _normalizeJsonValue(Object? v) {
    if (v == null) return null;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v;
    if (v is String) return v;
    return v.toString();
  }
}
