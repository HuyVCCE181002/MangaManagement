import '../../domain/entities/review.dart';
import '../../domain/repositories/user_interaction_repository.dart';
import '../datasources/user_interaction_local_datasource.dart';
import '../models/review_model.dart';

class UserInteractionRepositoryImpl implements UserInteractionRepository {
  final UserInteractionLocalDataSource localDataSource;

  UserInteractionRepositoryImpl({required this.localDataSource});

  @override
  Future<List<String>> getFavoriteMangaIds() async {
    return await localDataSource.getFavoriteIds();
  }

  @override
  Future<bool> toggleFavorite(String mangaId) async {
    final ids = await localDataSource.getFavoriteIds();
    final updatedIds = List<String>.from(ids);

    bool isNowFav;
    if (updatedIds.contains(mangaId)) {
      updatedIds.remove(mangaId);
      isNowFav = false;
    } else {
      updatedIds.add(mangaId);
      isNowFav = true;
    }

    await localDataSource.saveFavoriteIds(updatedIds);
    return isNowFav;
  }

  @override
  Future<bool> isFavorite(String mangaId) async {
    final ids = await localDataSource.getFavoriteIds();
    return ids.contains(mangaId);
  }

  @override
  Future<Review?> getReviewForManga(String mangaId) async {
    final reviews = await localDataSource.getReviews();
    final model = reviews[mangaId];
    return model?.toEntity();
  }

  @override
  Future<Review> saveReview(Review review) async {
    final reviews = await localDataSource.getReviews();
    reviews[review.mangaId] = ReviewModel.fromEntity(review);
    await localDataSource.saveReviews(reviews);
    return review;
  }

  @override
  Future<void> deleteReview(String mangaId) async {
    final reviews = await localDataSource.getReviews();
    reviews.remove(mangaId);
    await localDataSource.saveReviews(reviews);
  }
}
