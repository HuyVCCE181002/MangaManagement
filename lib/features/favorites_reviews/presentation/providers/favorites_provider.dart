import 'package:flutter/foundation.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/user_interaction_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  final UserInteractionRepository repository;

  FavoritesProvider({required this.repository});

  Set<String> _favoriteIds = {};
  final Map<String, Review> _reviews = {};
  bool _isLoading = false;

  Set<String> get favoriteIds => _favoriteIds;
  int get favoriteCount => _favoriteIds.length;
  bool get isLoading => _isLoading;

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final ids = await repository.getFavoriteMangaIds();
      _favoriteIds = ids.toSet();
    } catch (e) {
      debugPrint('Lỗi tải danh sách yêu thích: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isFavorite(String mangaId) {
    return _favoriteIds.contains(mangaId);
  }

  Future<bool> toggleFavorite(String mangaId) async {
    try {
      final isNowFav = await repository.toggleFavorite(mangaId);
      if (isNowFav) {
        _favoriteIds.add(mangaId);
      } else {
        _favoriteIds.remove(mangaId);
      }
      notifyListeners();
      return isNowFav;
    } catch (e) {
      debugPrint('Lỗi toggle favorite: $e');
      return isFavorite(mangaId);
    }
  }

  Review? getReview(String mangaId) {
    return _reviews[mangaId];
  }

  Future<void> loadReviewForManga(String mangaId) async {
    try {
      final review = await repository.getReviewForManga(mangaId);
      if (review != null) {
        _reviews[mangaId] = review;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Lỗi tải review: $e');
    }
  }

  Future<void> saveReview(Review review) async {
    try {
      final saved = await repository.saveReview(review);
      _reviews[saved.mangaId] = saved;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi lưu review: $e');
    }
  }

  Future<void> deleteReview(String mangaId) async {
    try {
      await repository.deleteReview(mangaId);
      _reviews.remove(mangaId);
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi xóa review: $e');
    }
  }
}
