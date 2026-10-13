import 'package:uuid/uuid.dart';
import '../models/genre.dart';
import 'backend_api_service.dart';
import 'database_helper.dart';
import 'services.dart';

class GenreService {
  GenreService._();
  static final GenreService instance = GenreService._();

  Future<List<Genre>> getGenres() async {
    final remote = await BackendApiService.instance.getGenres();
    if (remote != null) return remote;
    return (await DatabaseHelper.instance.getAllGenres()).map(Genre.fromMap).toList();
  }

  Future<void> createGenre(String name) async {
    final cleaned = name.trim();
    _validate(cleaned);
    final id = const Uuid().v4();
    if (await BackendApiService.instance.getGenres() != null) {
      await BackendApiService.instance.createGenre(id, cleaned);
      return;
    }
    await DatabaseHelper.instance.insertGenre(id, cleaned);
  }

  Future<void> renameGenre(Genre genre, String newName) async {
    final cleaned = newName.trim();
    _validate(cleaned);
    if (await BackendApiService.instance.getGenres() != null) {
      await BackendApiService.instance.renameGenre(genre.id, cleaned);
      return;
    }
    await DatabaseHelper.instance.renameGenre(genre.id, genre.name, cleaned);
    MangaService.instance.invalidateCache();
  }

  Future<void> deleteGenre(Genre genre) async {
    if (await BackendApiService.instance.getGenres() != null) {
      await BackendApiService.instance.deleteGenre(genre.id);
      return;
    }
    await DatabaseHelper.instance.deleteGenre(genre.id, genre.name);
  }

  void _validate(String name) {
    if (name.isEmpty) throw const FormatException('Tên thể loại không được để trống.');
    if (name.length > 40) throw const FormatException('Tên thể loại tối đa 40 ký tự.');
  }
}
