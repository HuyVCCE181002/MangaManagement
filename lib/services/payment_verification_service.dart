import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/payment_order.dart';
import '../models/user.dart';

class PaymentApiException implements Exception {
  final String message;
  final int? statusCode;
  const PaymentApiException(this.message, {this.statusCode});
  bool get isUnavailable => statusCode == 503;
  @override
  String toString() => message;
}

/// Authenticated transport. Provider keys are only configured on the server.
class PaymentVerificationService {
  static final instance = PaymentVerificationService._internal();
  PaymentVerificationService._internal();
  static const configuredBaseUrl = String.fromEnvironment(
    'PAYMENT_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  /// Android emulator không thấy 127.0.0.1 của máy host — map sang 10.0.2.2.
  static String get baseUrl {
    if (kIsWeb) return configuredBaseUrl;
    final uri = Uri.parse(configuredBaseUrl);
    if (defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return configuredBaseUrl;
  }
  String? _token;
  String? _username;
  String? _password;
  DateTime? _tokenExpiry;

  Uri _uri(String path) {
    final uri = Uri.parse('$baseUrl$path');
    if (uri.scheme != 'https' &&
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)) {
      throw const PaymentApiException('Backend thanh toán phải sử dụng HTTPS.');
    }
    return uri;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentApiException(
        body['error'] as String? ?? 'Không kết nối được backend thanh toán.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  /// `ready=true` khi SePay webhook đã bật. 503 khi tạo đơn là trạng thái
  /// cấu hình, không phải lỗi mạng.
  Future<({bool reachable, bool ready})> health() async {
    try {
      final response = await http
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return (reachable: true, ready: false);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (reachable: true, ready: body['ready'] == true);
    } catch (_) {
      return (reachable: false, ready: false);
    }
  }

  Future<void> _authenticate(AppUser user) async {
    if (user.isGuest) {
      throw const PaymentApiException('Vui lòng đăng nhập để nạp coins.');
    }
    if (_username == user.username &&
        _password == user.password &&
        _token != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return;
    }
    final response = await http
        .post(
          _uri('/sessions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': user.username,
            'password': user.password,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final body = _decode(response);
    _token = body['token'] as String;
    _tokenExpiry = DateTime.parse(body['expiresAt'] as String);
    _username = user.username;
    _password = user.password;
  }

  Future<Map<String, dynamic>> _request(
    AppUser user,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? requestKey,
  }) async {
    try {
      await _authenticate(user);
      final headers = {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };
      if (requestKey != null) headers['Idempotency-Key'] = requestKey;
      final uri = _uri(path);
      final response =
          await (method == 'POST'
                  ? http.post(uri, headers: headers, body: jsonEncode(body))
                  : method == 'DELETE'
                  ? http.delete(uri, headers: headers)
                  : http.get(uri, headers: headers))
              .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        _token = null;
      }
      return _decode(response);
    } on PaymentApiException {
      rethrow;
    } catch (_) {
      throw const PaymentApiException(
        'Không kết nối được máy chủ thanh toán. Vui lòng thử lại; không chuyển tiền khi chưa có mã đơn.',
      );
    }
  }

  Future<PaymentOrder> createOrder({
    required AppUser user,
    required String packageId,
    required String promoCode,
    required String requestKey,
  }) async => PaymentOrder.fromJson(
    await _request(
      user,
      '/payments/orders',
      method: 'POST',
      requestKey: requestKey,
      body: {'packageId': packageId, 'promoCode': promoCode},
    ),
  );

  Future<PaymentOrder> getOrder(AppUser user, String id) async =>
      PaymentOrder.fromJson(await _request(user, '/payments/orders/$id'));

  Future<List<PaymentOrder>> getOrders(AppUser user) async {
    final body = await _request(user, '/payments/orders');
    return (body['orders'] as List)
        .map((item) => PaymentOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentOrder> cancelOrder(AppUser user, String id) async =>
      PaymentOrder.fromJson(
        await _request(user, '/payments/orders/$id', method: 'DELETE'),
      );
}
