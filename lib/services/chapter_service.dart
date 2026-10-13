import '../models/chapter.dart';
import 'database_helper.dart';

/// Dịch vụ quản lý nghiệp vụ và truy xuất dữ liệu Chapter (Clean Architecture Service)
class ChapterService {
  // Singleton pattern
  static final ChapterService instance = ChapterService._internal();
  ChapterService._internal();

  // Bộ nhớ đệm danh sách chapter theo từng mangaId: mangaId -> List<Chapter>
  final Map<String, List<Chapter>> _mangaChaptersCache = {};

  // Bộ nhớ đệm lịch sử mua chương theo từng user: userId -> Set<String> chapterIds
  final Map<String, Set<String>> _userPurchasedCache = {};

  /// Lấy danh sách chapter của truyện tranh từ SQLite (hoặc từ cache)
  Future<List<Chapter>> getChapters(
    String mangaId, {
    bool forceRefresh = false,
  }) async {
    if (_mangaChaptersCache.containsKey(mangaId) && !forceRefresh) {
      return List.from(_mangaChaptersCache[mangaId]!);
    }

    final chapters = await DatabaseHelper.instance.getChaptersByMangaId(mangaId);
    _mangaChaptersCache[mangaId] = chapters;
    return List.from(chapters);
  }

  /// Lấy thông tin chi tiết một chapter theo ID
  Future<Chapter?> getChapterById(String id) async {
    // Tìm nhanh trong cache
    for (final list in _mangaChaptersCache.values) {
      for (final chapter in list) {
        if (chapter.id == id) return chapter;
      }
    }
    return await DatabaseHelper.instance.getChapterById(id);
  }

  /// Thêm mới chapter
  Future<void> addChapter(Chapter chapter) async {
    await DatabaseHelper.instance.insertChapter(chapter);
    final list = _mangaChaptersCache[chapter.mangaId];
    if (list != null) {
      list.add(chapter);
      list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    }
  }

  /// Cập nhật thông tin chapter vào SQLite và đồng bộ cache
  Future<void> updateChapter(Chapter chapter) async {
    await DatabaseHelper.instance.updateChapterData(chapter);
    final list = _mangaChaptersCache[chapter.mangaId];
    if (list != null) {
      final index = list.indexWhere((c) => c.id == chapter.id);
      if (index != -1) {
        list[index] = chapter;
        list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
      } else {
        list.add(chapter);
        list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
      }
    }
  }

  /// Xóa chapter (mặc định xóa mềm, có hỗ trợ xóa vĩnh viễn)
  Future<void> deleteChapter(
    String mangaId,
    String chapterId, {
    bool permanent = false,
  }) async {
    if (permanent) {
      await DatabaseHelper.instance.deleteChapterPermanently(chapterId);
    } else {
      await DatabaseHelper.instance.softDeleteChapter(chapterId);
    }
    final list = _mangaChaptersCache[mangaId];
    if (list != null) {
      list.removeWhere((c) => c.id == chapterId);
    }
  }

  /// Xóa mềm chapter (soft delete)
  Future<void> softDeleteChapter(String mangaId, String chapterId) async {
    await deleteChapter(mangaId, chapterId, permanent: false);
  }

  /// Kiểm tra số chương đã tồn tại chưa
  Future<bool> isChapterNumberTaken(
    String mangaId,
    int chapterNumber, {
    String? excludeChapterId,
  }) async {
    return await DatabaseHelper.instance.isChapterNumberTaken(
      mangaId,
      chapterNumber,
      excludeChapterId: excludeChapterId,
    );
  }

  /// Lấy tập hợp ID các chương mà người dùng đã mua
  Future<Set<String>> getPurchasedChapterIds(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (_userPurchasedCache.containsKey(userId) && !forceRefresh) {
      return Set.from(_userPurchasedCache[userId]!);
    }
    final ids = await DatabaseHelper.instance.getPurchasedChapterIds(userId);
    _userPurchasedCache[userId] = ids;
    return Set.from(ids);
  }

  /// Kiểm tra xem người dùng đã mua chương này chưa
  Future<bool> isChapterPurchased(String userId, String chapterId) async {
    if (_userPurchasedCache.containsKey(userId)) {
      return _userPurchasedCache[userId]!.contains(chapterId);
    }
    return await DatabaseHelper.instance.isChapterPurchasedByUser(userId, chapterId);
  }

  /// Thực hiện mua và mở khóa chương cho người dùng
  Future<void> purchaseChapter(String userId, String chapterId) async {
    await DatabaseHelper.instance.purchaseChapter(userId, chapterId);
    if (_userPurchasedCache.containsKey(userId)) {
      _userPurchasedCache[userId]!.add(chapterId);
    } else {
      _userPurchasedCache[userId] = {chapterId};
    }
  }

  /// Làm rỗng bộ nhớ đệm khi cần đồng bộ mới hoàn toàn
  void clearCache() {
    _mangaChaptersCache.clear();
    _userPurchasedCache.clear();
  }
}
