
// Minimal input model for creating/upserting a book in `books`.
// (Used for manual entry now; API entry later.)

class BookDraft {
  final String title;
  final String? author;
  final int? year;
  final String? description;
  final String? genres; // comma-separated
  final String? coverUrl;
  final String? isbn10;
  final String? isbn13;
  final String? externalSource;
  final String? externalId;

  const BookDraft({
    required this.title,
    this.author,
    this.year,
    this.description,
    this.genres,
    this.coverUrl,
    this.isbn10,
    this.isbn13,
    this.externalSource,
    this.externalId,
  });
}
