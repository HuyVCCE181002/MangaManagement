import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import 'api_exception.dart';

/// Client tương tác REST API với đầy đủ các phương thức HTTP và xử lý lỗi
class ApiClient {
  final http.Client _client;
  final String _baseUrl;

  ApiClient({
    http.Client? client,
    String baseUrl = ApiEndpoints.baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$cleanPath').replace(
      queryParameters: queryParameters?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await _client
          .get(uri, headers: _defaultHeaders)
          .timeout(const Duration(milliseconds: ApiEndpoints.connectTimeoutMs));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Quá thời gian kết nối tới máy chủ.');
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _client
          .post(uri, headers: _defaultHeaders, body: jsonEncode(body ?? {}))
          .timeout(const Duration(milliseconds: ApiEndpoints.connectTimeoutMs));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Quá thời gian kết nối tới máy chủ.');
    }
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = _buildUri(path);
      final response = await _client
          .put(uri, headers: _defaultHeaders, body: jsonEncode(body ?? {}))
          .timeout(const Duration(milliseconds: ApiEndpoints.connectTimeoutMs));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Quá thời gian kết nối tới máy chủ.');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final uri = _buildUri(path);
      final response = await _client
          .delete(uri, headers: _defaultHeaders)
          .timeout(const Duration(milliseconds: ApiEndpoints.connectTimeoutMs));
      return _processResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Quá thời gian kết nối tới máy chủ.');
    }
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (statusCode == 404) {
      throw NotFoundException();
    } else {
      throw ServerException(
        'Yêu cầu thất bại với mã lỗi $statusCode',
        statusCode,
      );
    }
  }

  void close() {
    _client.close();
  }
}
