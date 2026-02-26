import '../models/book.dart';

abstract class BooksRepository {
  Future<List<Book>> getBooks();

  Future<Book?> getBookById(String id);

  Future<void> addBook(Book book);

  Future<void> updateBook(Book book);

  Future<void> deleteBook(String id);
}
