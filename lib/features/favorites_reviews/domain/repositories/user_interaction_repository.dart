import '../entities/review.dart';

abstract class UserInteractionRepository {
  /// Lấy danh sách ID các manga được yêu thích
  Future<List<String>> getFavoriteMangaIds();

  /// Đảo trạng thái yêu thích (Favorite / Unfavorite)
  Future<bool> toggleFavorite(String mangaId);

  /// Kiểm tra manga có được yêu thích hay không
  Future<bool> isFavorite(String mangaId);

  /// Lấy review của người dùng cho một manga
  Future<Review?> getReviewForManga(String mangaId);

  /// Lưu hoặc cập nhật review cho manga
  Future<Review> saveReview(Review review);

  /// Xóa review
  Future<void> deleteReview(String mangaId);
}
