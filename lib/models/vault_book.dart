
// Combined view model for UI (Vault entry + Book metadata).

class VaultBook {
  // user_books
  final int userBookId;
  final int status; // 0=Want, 1=Reading, 2=Finished
  final int progressPercent; // 0..100
  final String? notes;
  final int addedAt;
  final int? startedAt;
  final int? finishedAt;
  final int updatedAt;

  // books
  final int bookId;
  final String title;
  final String? author;
  final int? year;
  final String? description;
  final String? genres; // comma-separated: "Horror, Fantasy"
  final String? coverUrl;
  final String? isbn10;
  final String? isbn13;
  final String? externalSource;
  final String? externalId;

  const VaultBook({
    required this.userBookId,
    required this.status,
    required this.progressPercent,
    required this.notes,
    required this.addedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.updatedAt,
    required this.bookId,
    required this.title,
    required this.author,
    required this.year,
    required this.description,
    required this.genres,
    required this.coverUrl,
    required this.isbn10,
    required this.isbn13,
    required this.externalSource,
    required this.externalId,
  });

  static VaultBook fromRow(Map<String, Object?> row) {
    return VaultBook(
      userBookId: row['user_book_id'] as int,
      status: row['status'] as int,
      progressPercent: row['progress_percent'] as int,
      notes: row['notes'] as String?,
      addedAt: row['added_at'] as int,
      startedAt: row['started_at'] as int?,
      finishedAt: row['finished_at'] as int?,
      updatedAt: row['user_updated_at'] as int,

      bookId: row['book_id'] as int,
      title: row['title'] as String,
      author: row['author'] as String?,
      year: row['year'] as int?,
      description: row['description'] as String?,
      genres: row['genres'] as String?,
      coverUrl: row['cover_url'] as String?,
      isbn10: row['isbn10'] as String?,
      isbn13: row['isbn13'] as String?,
      externalSource: row['external_source'] as String?,
      externalId: row['external_id'] as String?,
    );
  }
}
