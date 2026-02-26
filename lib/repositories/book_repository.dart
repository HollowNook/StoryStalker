
// BookRepository:
// - addToVault(): ensures row exists in `books`, then creates `user_books` entry
// - getVaultBooks(): JOIN query for list view
// - updateVaultEntry(): status/progress/notes updates (deliberate save)
// - removeFromVault(): deletes user_books row (books row stays if you later want cached results)

import 'package:sqflite/sqflite.dart';

import '../data/database/app_database.dart';
import '../models/book_draft.dart';
import '../models/vault_book.dart';

class BookRepository {
  BookRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  // -------------------------
  // Public API
  // -------------------------

  /// Add a book to the user's vault.
  /// This will:
  /// 1) Insert or update a row in `books` (metadata)
  /// 2) Insert a row into `user_books` (vault state)
  ///
  /// Returns the created VaultBook.
  Future<VaultBook> addToVault({
    required BookDraft book,
    int initialStatus = 0, // Want
  }) async {
    final db = await _database.db;
    final now = _nowMs();

    return db.transaction((txn) async {
      final bookId = await _upsertBook(txn, book, now);

      // If already in vault, just return existing entry.
      final existingUserBookId = await _findUserBookIdByBookId(txn, bookId);
      if (existingUserBookId != null) {
        final existing = await _getVaultBookByUserBookId(txn, existingUserBookId);
        if (existing == null) {
          throw StateError('Vault entry existed but could not be loaded.');
        }
        return existing;
      }

      final userBookId = await txn.insert(
        'user_books',
        {
          'book_id': bookId,
          'status': initialStatus,
          'progress_percent': 0,
          'notes': null,
          'added_at': now,
          'started_at': null,
          'finished_at': null,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final created = await _getVaultBookByUserBookId(txn, userBookId);
      if (created == null) {
        throw StateError('Failed to load vault book after insert.');
      }
      return created;
    });
  }

  /// Returns all books in the user's vault (JOIN user_books + books).
  Future<List<VaultBook>> getVaultBooks({
    int? status, // optional filter
    String? genreContains, // optional filter (simple contains)
    String? query, // optional title/author contains
  }) async {
    final db = await _database.db;

    final whereParts = <String>[];
    final args = <Object?>[];

    if (status != null) {
      whereParts.add('ub.status = ?');
      args.add(status);
    }

    if (genreContains != null && genreContains.trim().isNotEmpty) {
      // Simple v1 filter. (Later you can token-match in Dart if you want exact matches.)
      whereParts.add('b.genres LIKE ?');
      args.add('%${genreContains.trim()}%');
    }

    if (query != null && query.trim().isNotEmpty) {
      whereParts.add('(b.title LIKE ? OR b.author LIKE ?)');
      args.add('%${query.trim()}%');
      args.add('%${query.trim()}%');
    }

    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final rows = await db.rawQuery(
      '''
SELECT
  ub.id               AS user_book_id,
  ub.status           AS status,
  ub.progress_percent AS progress_percent,
  ub.notes            AS notes,
  ub.added_at         AS added_at,
  ub.started_at       AS started_at,
  ub.finished_at      AS finished_at,
  ub.updated_at       AS user_updated_at,

  b.id                AS book_id,
  b.title             AS title,
  b.author            AS author,
  b.year              AS year,
  b.description       AS description,
  b.genres            AS genres,
  b.cover_url         AS cover_url,
  b.isbn10            AS isbn10,
  b.isbn13            AS isbn13,
  b.external_source   AS external_source,
  b.external_id       AS external_id
FROM user_books ub
JOIN books b ON b.id = ub.book_id
${where == null ? '' : 'WHERE $where'}
ORDER BY ub.updated_at DESC;
''',
      args,
    );

    return rows.map(VaultBook.fromRow).toList();
  }

  /// Load one vault book by its user_books.id
  Future<VaultBook?> getVaultBookByUserBookId(int userBookId) async {
    final db = await _database.db;
    return _getVaultBookByUserBookId(db, userBookId);
  }

  /// Update vault-only fields (deliberate save):
  /// - status
  /// - progressPercent
  /// - notes
  ///
  /// Also auto-populates started_at / finished_at for convenience:
  /// - if status becomes Reading and started_at is null -> set started_at
  /// - if status becomes Finished -> set finished_at + progressPercent to 100 (unless you override)
  Future<void> updateVaultEntry({
    required int userBookId,
    int? status, // 0,1,2
    int? progressPercent, // 0..100
    String? notes,
  }) async {
    final db = await _database.db;
    final now = _nowMs();

    await db.transaction((txn) async {
      final current = await txn.query(
        'user_books',
        columns: ['status', 'progress_percent', 'started_at', 'finished_at'],
        where: 'id = ?',
        whereArgs: [userBookId],
        limit: 1,
      );

      if (current.isEmpty) {
        throw StateError('No vault entry found for userBookId=$userBookId');
      }

      final cur = current.first;
      final curStatus = cur['status'] as int;
      final curStartedAt = cur['started_at'] as int?;
      final curFinishedAt = cur['finished_at'] as int?;

      final updates = <String, Object?>{
        'updated_at': now,
      };

      int? newStatus = status;
      int? newProgress = progressPercent;

      if (newStatus != null) {
        updates['status'] = newStatus;

        // Auto-start timestamp when switching to Reading.
        if (newStatus == 1 && curStartedAt == null) {
          updates['started_at'] = now;
        }

        // Auto-finish timestamp when switching to Finished.
        if (newStatus == 2 && curFinishedAt == null) {
          updates['finished_at'] = now;
          // If user marks finished but forgets to set progress, force to 100.
          newProgress ??= 100;
        }
      } else {
        // If no explicit status, but progress hits 100 and current status isn't Finished, you can decide
        // later whether to auto-finish. For v1: we DO NOT auto-change status without the user.
      }

      if (newProgress != null) {
        final clamped = newProgress.clamp(0, 100);
        updates['progress_percent'] = clamped;

        // If progress moved back below 100, don't unset finished_at automatically.
        // Deliberate changes only.
      }

      if (notes != null) {
        updates['notes'] = notes;
      }

      // If nothing meaningful changed, still okay; we just updated timestamp.
      await txn.update(
        'user_books',
        updates,
        where: 'id = ?',
        whereArgs: [userBookId],
      );

      // Optional: if status switched away from Reading/Finished, we do not clear timestamps in v1.
      // Keep it simple & deliberate.
      final _ = curStatus; // silence unused warnings if you comment logic above.
    });
  }

  /// Remove from vault (deletes row in user_books).
  /// By design, `books` entry remains as cached metadata.
  Future<void> removeFromVault(int userBookId) async {
    final db = await _database.db;
    await db.delete('user_books', where: 'id = ?', whereArgs: [userBookId]);
  }

  // -------------------------
  // Internals
  // -------------------------

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<int?> _findUserBookIdByBookId(DatabaseExecutor db, int bookId) async {
    final rows = await db.query(
      'user_books',
      columns: ['id'],
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<VaultBook?> _getVaultBookByUserBookId(DatabaseExecutor db, int userBookId) async {
    final rows = await db.rawQuery(
      '''
SELECT
  ub.id               AS user_book_id,
  ub.status           AS status,
  ub.progress_percent AS progress_percent,
  ub.notes            AS notes,
  ub.added_at         AS added_at,
  ub.started_at       AS started_at,
  ub.finished_at      AS finished_at,
  ub.updated_at       AS user_updated_at,

  b.id                AS book_id,
  b.title             AS title,
  b.author            AS author,
  b.year              AS year,
  b.description       AS description,
  b.genres            AS genres,
  b.cover_url         AS cover_url,
  b.isbn10            AS isbn10,
  b.isbn13            AS isbn13,
  b.external_source   AS external_source,
  b.external_id       AS external_id
FROM user_books ub
JOIN books b ON b.id = ub.book_id
WHERE ub.id = ?
LIMIT 1;
''',
      [userBookId],
    );

    if (rows.isEmpty) return null;
    return VaultBook.fromRow(rows.first);
  }

  /// Insert/update into `books`.
  ///
  /// Upsert strategy:
  /// - If (external_source + external_id) provided => try to find existing by that pair.
  /// - Otherwise insert a new row (manual entry).
  ///
  /// Later, if you want to de-dupe manual entries too, you can add matching by (title+author+year).
  Future<int> _upsertBook(DatabaseExecutor db, BookDraft book, int nowMs) async {
    final hasExternal = (book.externalSource != null &&
        book.externalSource!.trim().isNotEmpty &&
        book.externalId != null &&
        book.externalId!.trim().isNotEmpty);

    if (hasExternal) {
      final existingId = await _findBookIdByExternal(
        db,
        book.externalSource!.trim(),
        book.externalId!.trim(),
      );

      if (existingId != null) {
        await db.update(
          'books',
          {
            'title': book.title,
            'author': book.author,
            'year': book.year,
            'description': book.description,
            'genres': book.genres,
            'cover_url': book.coverUrl,
            'isbn10': book.isbn10,
            'isbn13': book.isbn13,
            'external_source': book.externalSource,
            'external_id': book.externalId,
            'updated_at': nowMs,
          },
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return existingId;
      }
    }

    // Insert new book
    final bookId = await db.insert(
      'books',
      {
        'title': book.title,
        'author': book.author,
        'year': book.year,
        'description': book.description,
        'genres': book.genres,
        'cover_url': book.coverUrl,
        'isbn10': book.isbn10,
        'isbn13': book.isbn13,
        'external_source': book.externalSource,
        'external_id': book.externalId,
        'created_at': nowMs,
        'updated_at': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return bookId;
  }

  Future<int?> _findBookIdByExternal(
    DatabaseExecutor db,
    String externalSource,
    String externalId,
  ) async {
    final rows = await db.query(
      'books',
      columns: ['id'],
      where: 'external_source = ? AND external_id = ?',
      whereArgs: [externalSource, externalId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }
}
