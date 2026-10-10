/// Các lớp ngoại lệ tùy chỉnh cho tầng mạng và dữ liệu
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại Wifi/4G.']);
}

class ServerException extends ApiException {
  ServerException([
    super.message = 'Máy chủ phản hồi lỗi. Vui lòng thử lại sau.',
    super.statusCode,
  ]);
}

class NotFoundException extends ApiException {
  NotFoundException([String message = 'Dữ liệu không tồn tại.'])
      : super(message, 404);
}

class CacheException implements Exception {
  final String message;
  CacheException([this.message = 'Lỗi truy xuất bộ nhớ cục bộ.']);

  @override
  String toString() => 'CacheException: $message';
}
