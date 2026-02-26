// lib/data/database/app_database.dart
//
// Story Stalker - v1.0 SQLite bootstrap (sqflite)
//
// Responsibilities:
// - Open the SQLite database (singleton)
// - Create schema on first install (version 1)
// - Provide upgrade hook for future versions (v1.5/v2)
//
// Notes:
// - We enable foreign keys via PRAGMA in onConfigure.
// - We create tables + indexes inside a transaction for safety.

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  static const String _dbFileName = 'story_stalker.db';
  static const int _dbVersion = 1;

  Database? _db;

  /// Get an open database instance (opens lazily; singleton).
  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final opened = await _open();
    _db = opened;
    return opened;
  }

  /// Close the database (handy for tests / teardown).
  Future<void> close() async {
    final existing = _db;
    if (existing == null) return;

    await existing.close();
    _db = null;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbFileName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce FK constraints.
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // =========================
      // books (metadata record)
      // =========================
      await txn.execute('''
CREATE TABLE IF NOT EXISTS books (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  title           TEXT    NOT NULL,
  author          TEXT,
  year            INTEGER,
  description     TEXT,
  genres          TEXT,             -- comma-separated list: "Horror, Fantasy"
  cover_url       TEXT,

  isbn10          TEXT,
  isbn13          TEXT,

  external_source TEXT,             -- e.g., "google_books", "openlibrary"
  external_id     TEXT,             -- API's unique ID for the book

  created_at      INTEGER NOT NULL, -- unix ms
  updated_at      INTEGER NOT NULL  -- unix ms
);
''');

      // Avoid duplicate imports when an API ID exists.
      await txn.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_books_external
  ON books (external_source, external_id);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_books_title
  ON books (title);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_books_author
  ON books (author);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_books_genres
  ON books (genres);
''');

      // =========================
      // user_books (vault record)
      // =========================
      await txn.execute('''
CREATE TABLE IF NOT EXISTS user_books (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id          INTEGER NOT NULL UNIQUE, -- one vault entry per book
  status           INTEGER NOT NULL DEFAULT 0, -- 0=Want, 1=Reading, 2=Finished

  progress_percent INTEGER NOT NULL DEFAULT 0, -- 0..100
  notes            TEXT,

  added_at         INTEGER NOT NULL, -- unix ms
  started_at       INTEGER,          -- unix ms nullable
  finished_at      INTEGER,          -- unix ms nullable
  updated_at       INTEGER NOT NULL, -- unix ms

  FOREIGN KEY (book_id) REFERENCES books(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (progress_percent BETWEEN 0 AND 100),
  CHECK (status IN (0, 1, 2))
);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_user_books_status
  ON user_books (status);
''');

      // =========================
      // prompts (prompt catalog)
      // =========================
      await txn.execute('''
CREATE TABLE IF NOT EXISTS prompts (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  text           TEXT    NOT NULL,

  milestone_type INTEGER NOT NULL,         -- 0=Origin, 1=Progress, 2=Completion
  is_active      INTEGER NOT NULL DEFAULT 1,

  created_at     INTEGER NOT NULL,         -- unix ms
  updated_at     INTEGER NOT NULL,         -- unix ms

  CHECK (milestone_type IN (0, 1, 2)),
  CHECK (is_active IN (0, 1))
);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_prompts_milestone
  ON prompts (milestone_type);
''');

      // ==========================================
      // user_book_prompts (3 selected per book)
      // ==========================================
      await txn.execute('''
CREATE TABLE IF NOT EXISTS user_book_prompts (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_book_id   INTEGER NOT NULL,
  prompt_id      INTEGER NOT NULL,

  slot           INTEGER NOT NULL,         -- 1..3
  replaced_once  INTEGER NOT NULL DEFAULT 0,
  selected_at    INTEGER NOT NULL,         -- unix ms
  updated_at     INTEGER NOT NULL,         -- unix ms

  FOREIGN KEY (user_book_id) REFERENCES user_books(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  FOREIGN KEY (prompt_id) REFERENCES prompts(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CHECK (slot IN (1, 2, 3)),
  CHECK (replaced_once IN (0, 1)),

  UNIQUE (user_book_id, slot),
  UNIQUE (user_book_id, prompt_id)
);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_user_book_prompts_user_book
  ON user_book_prompts (user_book_id);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_user_book_prompts_prompt
  ON user_book_prompts (prompt_id);
''');

      // ==========================================
      // prompt_responses (reflection; 210 char cap)
      // ==========================================
      await txn.execute('''
CREATE TABLE IF NOT EXISTS prompt_responses (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  user_book_prompt_id INTEGER NOT NULL,

  response_text       TEXT    NOT NULL,
  created_at          INTEGER NOT NULL, -- unix ms

  FOREIGN KEY (user_book_prompt_id) REFERENCES user_book_prompts(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  CHECK (length(response_text) <= 210)
);
''');

      await txn.execute('''
CREATE INDEX IF NOT EXISTS idx_prompt_responses_ubp
  ON prompt_responses (user_book_prompt_id);
''');

      // If you want an explicit schema marker (optional; `openDatabase(version: ...)` is the main driver)
      await txn.execute('PRAGMA user_version = $_dbVersion;');
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 has no upgrades yet.
    // When you add v1.5/v2 migrations, do something like:
    //
    // if (oldVersion < 2) { ... }
    // if (oldVersion < 3) { ... }
    //
    // Keep migrations forward-only. No dropping tables in production.
  }
}
