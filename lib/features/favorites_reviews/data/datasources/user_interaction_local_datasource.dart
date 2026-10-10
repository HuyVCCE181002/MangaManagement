import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/review_model.dart';

abstract class UserInteractionLocalDataSource {
  Future<List<String>> getFavoriteIds();
  Future<void> saveFavoriteIds(List<String> ids);
  Future<Map<String, ReviewModel>> getReviews();
  Future<void> saveReviews(Map<String, ReviewModel> reviews);
}

class UserInteractionLocalDataSourceImpl implements UserInteractionLocalDataSource {
  final LocalStorageService storageService;

  UserInteractionLocalDataSourceImpl(this.storageService);

  @override
  Future<List<String>> getFavoriteIds() async {
    return storageService.getStringList(AppConstants.prefFavoritesKey) ?? [];
  }

  @override
  Future<void> saveFavoriteIds(List<String> ids) async {
    await storageService.setStringList(AppConstants.prefFavoritesKey, ids);
  }

  @override
  Future<Map<String, ReviewModel>> getReviews() async {
    final list = storageService.getJsonList(AppConstants.prefReviewsKey);
    if (list == null) return {};

    final Map<String, ReviewModel> result = {};
    for (final item in list) {
      final model = ReviewModel.fromJson(item);
      result[model.mangaId] = model;
    }
    return result;
  }

  @override
  Future<void> saveReviews(Map<String, ReviewModel> reviews) async {
    final list = reviews.values.map((r) => r.toJson()).toList();
    await storageService.setJsonList(AppConstants.prefReviewsKey, list);
  }
}
