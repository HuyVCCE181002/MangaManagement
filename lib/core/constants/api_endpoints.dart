/// Cấu hình các API Endpoints cho hệ thống REST API
class ApiEndpoints {
  ApiEndpoints._();

  // URL gốc của máy chủ backend (có thể đổi sang Mockoon, MockAPI.io hoặc server local)
  static const String baseUrl = 'https://api.mangavault.local/v1';

  // Endpoints
  static const String mangas = '/mangas';
  static String mangaDetail(String id) => '/mangas/$id';
  static const String genres = '/genres';
  static const String userReviews = '/user/reviews';

  // Thời gian chờ mạng mặc định (milliseconds)
  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 10000;
}
