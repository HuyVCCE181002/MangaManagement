import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/manga_model.dart';

abstract class MangaLocalDataSource {
  Future<List<MangaModel>?> getCachedMangas();
  Future<void> cacheMangas(List<MangaModel> mangas);
  Future<void> saveManga(MangaModel manga);
  Future<void> deleteCachedManga(String id);
  Future<void> clearCache();
}

class MangaLocalDataSourceImpl implements MangaLocalDataSource {
  final LocalStorageService storageService;

  MangaLocalDataSourceImpl(this.storageService);

  @override
  Future<List<MangaModel>?> getCachedMangas() async {
    final jsonList = storageService.getJsonList(AppConstants.prefMangaCacheKey);
    if (jsonList == null || jsonList.isEmpty) return null;

    return jsonList.map((item) => MangaModel.fromJson(item)).toList();
  }

  @override
  Future<void> cacheMangas(List<MangaModel> mangas) async {
    final jsonList = mangas.map((m) => m.toJson()).toList();
    await storageService.setJsonList(AppConstants.prefMangaCacheKey, jsonList);
    await storageService.setString(
      AppConstants.prefLastCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> saveManga(MangaModel manga) async {
    final cached = await getCachedMangas() ?? [];
    final index = cached.indexWhere((m) => m.id == manga.id);
    if (index != -1) {
      cached[index] = manga;
    } else {
      cached.insert(0, manga);
    }
    await cacheMangas(cached);
  }

  @override
  Future<void> deleteCachedManga(String id) async {
    final cached = await getCachedMangas() ?? [];
    cached.removeWhere((m) => m.id == id);
    await cacheMangas(cached);
  }

  @override
  Future<void> clearCache() async {
    await storageService.remove(AppConstants.prefMangaCacheKey);
  }
}
