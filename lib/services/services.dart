import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga.dart';

class MangaService {
  static const String _storageKey = 'manga_vault_data_v2';

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

  // Dữ liệu mẫu khởi tạo ban đầu
  final List<Manga> _initialMockMangas = [
    Manga(
      id: '1',
      title: 'One Piece',
      author: 'Eiichiro Oda',
      description:
          'Monkey D. Luffy cùng băng Mũ Rơm giương buồm ra khơi để tìm kiếm kho báu huyền thoại One Piece và trở thành Vua Hải Tặc mới.',
      coverUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
      genre: 'Action',
      status: 'Ongoing',
      totalChapters: 1115,
      currentChapter: 1080,
      rating: 9.8,
      isFavorite: true,
    ),
    Manga(
      id: '2',
      title: 'Solo Leveling',
      author: 'Chugong',
      description:
          'Sung Jinwoo - thợ săn yếu nhất cấp E - bất ngờ nhận được hệ thống thăng cấp bí ẩn trong một hầm ngục kép nguy hiểm.',
      coverUrl:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80',
      genre: 'Fantasy',
      status: 'Completed',
      totalChapters: 200,
      currentChapter: 200,
      rating: 9.6,
      isFavorite: true,
    ),
    Manga(
      id: '3',
      title: 'Frieren: Beyond Journey\'s End',
      author: 'Kanehito Yamada',
      description:
          'Chuyến hành trình của pháp sư Elf Frieren tìm hiểu về con người và cảm xúc sau khi tổ đội anh hùng đã đánh bại Ma Vương.',
      coverUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      genre: 'Adventure',
      status: 'Ongoing',
      totalChapters: 130,
      currentChapter: 95,
      rating: 9.7,
      isFavorite: false,
    ),
    Manga(
      id: '4',
      title: 'Jujutsu Kaisen',
      author: 'Gege Akutami',
      description:
          'Yuji Itadori nuốt ngón tay nguyền hồn Sukuna và bước chân vào thế giới Chú Thuật Sư đầy hiểm nguy để bảo vệ người vô tội.',
      coverUrl:
          'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=600&auto=format&fit=crop&q=80',
      genre: 'Action',
      status: 'Completed',
      totalChapters: 271,
      currentChapter: 271,
      rating: 9.2,
      isFavorite: false,
    ),
    Manga(
      id: '5',
      title: 'Spy x Family',
      author: 'Tatsuya Endo',
      description:
          'Điệp viên Twilight phải lập gia đình giả nhằm thực hiện nhiệm vụ, mà không biết vợ là sát thủ và con gái có năng lực đọc suy nghĩ.',
      coverUrl:
          'https://images.unsplash.com/photo-1563089145-599997674d42?w=600&auto=format&fit=crop&q=80',
      genre: 'Comedy',
      status: 'Ongoing',
      totalChapters: 104,
      currentChapter: 75,
      rating: 9.4,
      isFavorite: true,
    ),
    Manga(
      id: '6',
      title: 'Blue Lock',
      author: 'Muneyuki Kaneshiro',
      description:
          'Dự án biệt lập tập hợp 300 tiền đạo trẻ xuất sắc nhất Nhật Bản nhằm tìm ra một chân sút ích kỷ và sắc bén nhất thế giới.',
      coverUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      genre: 'Sports',
      status: 'Ongoing',
      totalChapters: 280,
      currentChapter: 240,
      rating: 9.1,
      isFavorite: false,
    ),
  ];

  /// Lấy toàn bộ danh sách manga
  Future<List<Manga>> getMangas() async {
    if (_cache.isNotEmpty) {
      return List.from(_cache);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      _cache = decoded.map((e) => Manga.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      _cache = List.from(_initialMockMangas);
      await _saveToDisk();
    }

    return List.from(_cache);
  }

  /// Tìm manga theo ID
  Manga? getMangaById(String id) {
    try {
      return _cache.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Thêm truyện mới
  Future<void> addManga(Manga manga) async {
    _cache.insert(0, manga);
    await _saveToDisk();
  }

  /// Cập nhật thông tin truyện
  Future<void> updateManga(Manga manga) async {
    final index = _cache.indexWhere((m) => m.id == manga.id);
    if (index != -1) {
      _cache[index] = manga;
      await _saveToDisk();
    }
  }

  /// Xóa truyện
  Future<void> deleteManga(String id) async {
    _cache.removeWhere((m) => m.id == id);
    await _saveToDisk();
  }

  /// Đảo trạng thái yêu thích
  Future<void> toggleFavorite(String id) async {
    final index = _cache.indexWhere((m) => m.id == id);
    if (index != -1) {
      final item = _cache[index];
      _cache[index] = item.copyWith(isFavorite: !item.isFavorite);
      await _saveToDisk();
    }
  }

  /// Cập nhật số chapter đang đọc
  Future<void> updateChapter(String id, int chapter) async {
    final index = _cache.indexWhere((m) => m.id == id);
    if (index != -1) {
      final item = _cache[index];
      _cache[index] = item.copyWith(
        currentChapter: chapter.clamp(0, item.totalChapters),
      );
      await _saveToDisk();
    }
  }

  /// Lưu vào SharedPreferences
  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_cache.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
