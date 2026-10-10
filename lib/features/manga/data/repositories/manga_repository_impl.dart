import '../../domain/entities/manga.dart';
import '../../domain/entities/manga_filter.dart';
import '../../domain/repositories/manga_repository.dart';
import '../datasources/manga_local_datasource.dart';
import '../datasources/manga_remote_datasource.dart';
import '../models/manga_model.dart';

class MangaRepositoryImpl implements MangaRepository {
  final MangaRemoteDataSource remoteDataSource;
  final MangaLocalDataSource localDataSource;

  MangaRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<Manga>> getMangas({MangaFilter? filter}) async {
    // 1. Kiểm tra Local Cache trước để phản hồi nhanh và hỗ trợ offline
    List<MangaModel>? models = await localDataSource.getCachedMangas();

    if (models == null || models.isEmpty) {
      // 2. Nếu chưa có cache, fetch từ Remote API và lưu vào cache
      models = await remoteDataSource.fetchMangas();
      await localDataSource.cacheMangas(models);
    }

    List<Manga> mangas = models.map((m) => m.toEntity()).toList();

    // 3. Áp dụng bộ lọc (filter) nếu có
    if (filter != null) {
      mangas = _applyFilter(mangas, filter);
    }

    return mangas;
  }

  @override
  Future<Manga> getMangaById(String id) async {
    final cached = await localDataSource.getCachedMangas();
    if (cached != null) {
      final found = cached.where((m) => m.id == id).toList();
      if (found.isNotEmpty) {
        return found.first.toEntity();
      }
    }

    final remoteModel = await remoteDataSource.fetchMangaById(id);
    await localDataSource.saveManga(remoteModel);
    return remoteModel.toEntity();
  }

  @override
  Future<Manga> createManga(Manga manga) async {
    final model = MangaModel.fromEntity(manga);
    final createdModel = await remoteDataSource.addManga(model);
    await localDataSource.saveManga(createdModel);
    return createdModel.toEntity();
  }

  @override
  Future<Manga> updateManga(Manga manga) async {
    final model = MangaModel.fromEntity(manga);
    final updatedModel = await remoteDataSource.updateManga(model);
    await localDataSource.saveManga(updatedModel);
    return updatedModel.toEntity();
  }

  @override
  Future<Manga> updateReadingProgress(String id, int currentChapter) async {
    final manga = await getMangaById(id);
    final updated = manga.copyWith(
      currentChapter: currentChapter,
      updatedAt: DateTime.now(),
    );
    return await updateManga(updated);
  }

  @override
  Future<void> deleteManga(String id) async {
    await remoteDataSource.deleteManga(id);
    await localDataSource.deleteCachedManga(id);
  }

  @override
  Future<List<Manga>> refreshRemoteData() async {
    final remoteList = await remoteDataSource.fetchMangas();
    await localDataSource.cacheMangas(remoteList);
    return remoteList.map((m) => m.toEntity()).toList();
  }

  List<Manga> _applyFilter(List<Manga> source, MangaFilter filter) {
    var result = List<Manga>.from(source);

    // Lọc theo từ khóa tìm kiếm (tiêu đề, tác giả)
    if (filter.query != null && filter.query!.trim().isNotEmpty) {
      final q = filter.query!.trim().toLowerCase();
      result = result.where((m) {
        final title = m.title.toLowerCase();
        final original = m.originalTitle?.toLowerCase() ?? '';
        final author = m.author.toLowerCase();
        return title.contains(q) || original.contains(q) || author.contains(q);
      }).toList();
    }

    // Lọc theo thể loại (chứa ít nhất một hoặc tất cả thể loại đã chọn)
    if (filter.genres.isNotEmpty) {
      result = result.where((m) {
        return filter.genres.any((g) => m.genres.contains(g));
      }).toList();
    }

    // Lọc theo trạng thái
    if (filter.status != null && filter.status!.isNotEmpty) {
      result = result
          .where((m) => m.status.toLowerCase() == filter.status!.toLowerCase())
          .toList();
    }

    // Lọc theo điểm rating tối thiểu
    if (filter.minRating != null && filter.minRating! > 0) {
      result = result.where((m) => m.rating >= filter.minRating!).toList();
    }

    // Sắp xếp
    switch (filter.sortBy) {
      case MangaSortBy.ratingDesc:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case MangaSortBy.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MangaSortBy.chaptersDesc:
        result.sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
        break;
      case MangaSortBy.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return result;
  }
}
