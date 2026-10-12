import '../models/manga.dart';
import 'database_helper.dart';

class MangaService {
  // Singleton instance dùng chung toàn app: MangaService.instance
  static final MangaService instance = MangaService._internal();
  MangaService._internal();

  static const List<String> genres = [
    'Tất cả',
    'Action',
    'Adventure',
    'Fantasy',
    'Comedy',
    'Romance',
    'Supernatural',
    'Sports',
  ];

  static const List<String> statuses = [
    'Ongoing',
    'Completed',
  ];

  // Bộ nhớ đệm danh sách truyện
  List<Manga> _cache = [];

  /// Lấy toàn bộ danh sách manga từ SQLite
  Future<List<Manga>> getMangas({bool forceRefresh = false}) async {
    if (_cache.isNotEmpty && !forceRefresh) {
      return List.from(_cache);
    }

    _cache = await DatabaseHelper.instance.getAllMangas();
    return List.from(_cache);
  }

  /// Tìm manga theo ID trong bộ nhớ cache
  Manga? getMangaById(String id) {
    try {
      return _cache.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Thêm truyện mới vào SQLite
  Future<void> addManga(Manga manga) async {
    await DatabaseHelper.instance.insertManga(manga);
    _cache.insert(0, manga);
  }

  /// Cập nhật thông tin truyện trong SQLite
  Future<void> updateManga(Manga manga) async {
    await DatabaseHelper.instance.updateManga(manga);
    final index = _cache.indexWhere((m) => m.id == manga.id);
    if (index != -1) {
      _cache[index] = manga;
    }
  }

  /// Xóa truyện khỏi SQLite
  Future<void> deleteManga(String id) async {
    await DatabaseHelper.instance.deleteManga(id);
    _cache.removeWhere((m) => m.id == id);
  }

  /// Đảo trạng thái yêu thích trong SQLite
  Future<void> toggleFavorite(String id) async {
    final index = _cache.indexWhere((m) => m.id == id);
    if (index != -1) {
      final item = _cache[index];
      final newFavoriteStatus = !item.isFavorite;
      await DatabaseHelper.instance.updateFavorite(id, newFavoriteStatus);
      _cache[index] = item.copyWith(isFavorite: newFavoriteStatus);
    }
  }

  /// Cập nhật số chapter đang đọc trong SQLite
  Future<void> updateChapter(String id, int chapter) async {
    final index = _cache.indexWhere((m) => m.id == id);
    if (index != -1) {
      final item = _cache[index];
      final clampedChapter = chapter.clamp(0, item.totalChapters);
      await DatabaseHelper.instance.updateChapter(id, clampedChapter);
      _cache[index] = item.copyWith(currentChapter: clampedChapter);
    }
  }

  /// Khôi phục dữ liệu mặc định ban đầu
  Future<void> resetToDefault() async {
    await DatabaseHelper.instance.resetToDefault();
    _cache = await DatabaseHelper.instance.getAllMangas();
  }
}
