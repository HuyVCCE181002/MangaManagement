/// Các hằng số nghiệp vụ dùng chung toàn ứng dụng
class AppConstants {
  AppConstants._();

  static const String appName = 'Manga Vault';
  static const String appVersion = '1.0.0';

  // Danh mục thể loại manga phổ biến
  static const List<String> availableGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Isekai',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Supernatural',
    'Horror',
    'Sports',
    'Shounen',
    'Seinen',
  ];

  // Trạng thái phát hành
  static const List<String> mangaStatuses = [
    'Ongoing',     // Đang tiến hành
    'Completed',   // Đã hoàn thành
    'Hiatus',      // Tạm ngưng
  ];

  // Keys lưu trữ Local Storage (SharedPreferences)
  static const String prefMangaCacheKey = 'cached_manga_list_v1';
  static const String prefFavoritesKey = 'cached_user_favorites_v1';
  static const String prefReviewsKey = 'cached_user_reviews_v1';
  static const String prefLastCacheTimeKey = 'cached_last_sync_time';

  // Placeholder ảnh mặc định khi mạng lỗi
  static const String defaultCoverUrl =
      'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80';
}
