class Book {
  final String id;
  final String title;
  final String shortDescription;

  final String? author;
  final int? year;

  final String? coverImagePath; // local path later
  final bool isRead;
  final bool isFavorite;
  final double? rating;

  const Book({
    required this.id,
    required this.title,
    required this.shortDescription,
    this.author,
    this.year,
    this.coverImagePath,
    this.isRead = false,
    this.isFavorite = false,
    this.rating,
  });

  /// For SQLite later
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'shortDescription': shortDescription,
      'author': author,
      'year': year,
      'coverImagePath': coverImagePath,
      'isRead': isRead ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'rating': rating,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      shortDescription: map['shortDescription'],
      author: map['author'],
      year: map['year'],
      coverImagePath: map['coverImagePath'],
      isRead: (map['isRead'] ?? 0) == 1,
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      rating: map['rating'],
    );
  }
}
