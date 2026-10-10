import 'package:flutter/foundation.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/manga_filter.dart';
import '../../domain/repositories/manga_repository.dart';

class MangaProvider extends ChangeNotifier {
  final MangaRepository repository;

  MangaProvider({required this.repository});

  List<Manga> _mangas = [];
  bool _isLoading = false;
  String? _errorMessage;
  MangaFilter _currentFilter = const MangaFilter();

  List<Manga> get mangas => _mangas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MangaFilter get currentFilter => _currentFilter;

  // Lấy danh sách truyện hoàn thành
  List<Manga> get completedMangas =>
      _mangas.where((m) => m.isCompleted).toList();

  // Lấy danh sách truyện đang tiến hành
  List<Manga> get ongoingMangas =>
      _mangas.where((m) => !m.isCompleted).toList();

  // Tải danh sách truyện
  Future<void> loadMangas({MangaFilter? filter}) async {
    _isLoading = true;
    _errorMessage = null;
    if (filter != null) {
      _currentFilter = filter;
    }
    notifyListeners();

    try {
      _mangas = await repository.getMangas(filter: _currentFilter);
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách truyện: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Thêm truyện mới (Create)
  Future<bool> addManga(Manga manga) async {
    try {
      final created = await repository.createManga(manga);
      _mangas.insert(0, created);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể thêm truyện: $e';
      notifyListeners();
      return false;
    }
  }

  // Cập nhật truyện (Update)
  Future<bool> updateManga(Manga manga) async {
    try {
      final updated = await repository.updateManga(manga);
      final index = _mangas.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        _mangas[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Không thể cập nhật truyện: $e';
      notifyListeners();
      return false;
    }
  }

  // Cập nhật tiến độ đọc nhanh
  Future<void> updateReadingChapter(String id, int newChapter) async {
    try {
      final updated = await repository.updateReadingProgress(id, newChapter);
      final index = _mangas.indexWhere((m) => m.id == id);
      if (index != -1) {
        _mangas[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật tiến độ đọc: $e';
      notifyListeners();
    }
  }

  // Xóa truyện (Delete)
  Future<bool> deleteManga(String id) async {
    try {
      await repository.deleteManga(id);
      _mangas.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể xóa truyện: $e';
      notifyListeners();
      return false;
    }
  }

  // Làm mới từ máy chủ (Pull to Refresh)
  Future<void> refresh() async {
    try {
      final refreshed = await repository.refreshRemoteData();
      _mangas = refreshed;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Lỗi đồng bộ dữ liệu: $e';
    } finally {
      notifyListeners();
    }
  }

  // Lấy chi tiết một truyện
  Manga? findMangaById(String id) {
    try {
      return _mangas.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
