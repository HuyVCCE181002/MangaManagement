import 'package:uuid/uuid.dart';

import '../models/genre.dart';

/// Mock API cho chức năng quản lý thể loại.
/// Dữ liệu chỉ nằm trong bộ nhớ và được khởi tạo lại khi chạy ứng dụng.
class GenreService {
  GenreService._();

  static final GenreService instance = GenreService._();

  static const Duration _mockDelay = Duration(milliseconds: 300);
  final Uuid _uuid = const Uuid();

  final List<Genre> _genres = [
    const Genre(id: 'genre-action', name: 'Action'),
    const Genre(id: 'genre-adventure', name: 'Adventure'),
    const Genre(id: 'genre-fantasy', name: 'Fantasy'),
    const Genre(id: 'genre-comedy', name: 'Comedy'),
    const Genre(id: 'genre-romance', name: 'Romance'),
    const Genre(id: 'genre-supernatural', name: 'Supernatural'),
    const Genre(id: 'genre-sports', name: 'Sports'),
  ];

  List<Genre> get genres => List.unmodifiable(_genres);

  Future<List<Genre>> getGenres() async {
    await Future<void>.delayed(_mockDelay);
    return genres;
  }

  Future<Genre> createGenre(String name) async {
    await Future<void>.delayed(_mockDelay);
    final normalizedName = _validateName(name);
    _ensureNameIsAvailable(normalizedName);

    final genre = Genre(id: _uuid.v4(), name: normalizedName);
    _genres.add(genre);
    return genre;
  }

  Future<Genre> updateGenre(String id, String name) async {
    await Future<void>.delayed(_mockDelay);
    final index = _genres.indexWhere((genre) => genre.id == id);
    if (index == -1) {
      throw const GenreServiceException('Không tìm thấy thể loại.');
    }

    final normalizedName = _validateName(name);
    _ensureNameIsAvailable(normalizedName, exceptId: id);

    final updatedGenre = _genres[index].copyWith(name: normalizedName);
    _genres[index] = updatedGenre;
    return updatedGenre;
  }

  Future<void> deleteGenre(String id) async {
    await Future<void>.delayed(_mockDelay);
    final index = _genres.indexWhere((genre) => genre.id == id);
    if (index == -1) {
      throw const GenreServiceException('Không tìm thấy thể loại.');
    }
    _genres.removeAt(index);
  }

  String _validateName(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const GenreServiceException('Tên thể loại không được để trống.');
    }
    return normalizedName;
  }

  void _ensureNameIsAvailable(String name, {String? exceptId}) {
    final alreadyExists = _genres.any(
      (genre) =>
          genre.id != exceptId &&
          genre.name.toLowerCase() == name.toLowerCase(),
    );
    if (alreadyExists) {
      throw const GenreServiceException('Thể loại này đã tồn tại.');
    }
  }
}

class GenreServiceException implements Exception {
  final String message;

  const GenreServiceException(this.message);

  @override
  String toString() => message;
}
