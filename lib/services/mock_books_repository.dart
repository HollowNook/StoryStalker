import 'dart:async';
import '../models/book.dart';
import 'books_repository.dart';

class MockBooksRepository implements BooksRepository {
  final List<Book> _books = [
    Book(
      id: '1',
      title: 'The Silent Ocean',
      shortDescription: 'A mysterious voyage across an uncharted sea.',
      author: 'M. Carter',
      year: 2018,
      isRead: true,
      rating: 4.5,
    ),
    Book(
      id: '2',
      title: 'Ashes of Tomorrow',
      shortDescription: 'A dystopian world rebuilding from collapse.',
      author: 'L. Nguyen',
      year: 2021,
      isFavorite: true,
    ),
    Book(
      id: '3',
      title: 'The Clockmaker’s Secret',
      shortDescription: 'A puzzle hidden inside time itself.',
      author: 'D. Rowan',
      year: 2015,
    ),
  ];

  @override
  Future<List<Book>> getBooks() async {
    // Simulate small delay like real DB
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_books);
  }

  @override
  Future<Book?> getBookById(String id) async {
    return _books.firstWhere(
      (b) => b.id == id,
      orElse: () => throw Exception('Book not found'),
    );
  }

  @override
  Future<void> addBook(Book book) async {
    _books.add(book);
  }

  @override
  Future<void> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _books[index] = book;
    }
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.removeWhere((b) => b.id == id);
  }
}
