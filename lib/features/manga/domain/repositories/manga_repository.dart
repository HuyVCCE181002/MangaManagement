import '../entities/manga.dart';
import '../entities/manga_filter.dart';

/// Hợp đồng trừu tượng (Interface) cho Manga Repository
abstract class MangaRepository {
  /// Lấy danh sách truyện có hỗ trợ lọc và phân loại
  Future<List<Manga>> getMangas({MangaFilter? filter});

  /// Lấy chi tiết một truyện theo ID
  Future<Manga> getMangaById(String id);

  /// Thêm mới một bộ truyện
  Future<Manga> createManga(Manga manga);

  /// Cập nhật thông tin truyện
  Future<Manga> updateManga(Manga manga);

  /// Cập nhật tiến độ đọc (số chapter hiện tại)
  Future<Manga> updateReadingProgress(String id, int currentChapter);

  /// Xóa một bộ truyện
  Future<void> deleteManga(String id);

  /// Làm mới bộ nhớ đệm (đồng bộ lại từ remote server)
  Future<List<Manga>> refreshRemoteData();
}
