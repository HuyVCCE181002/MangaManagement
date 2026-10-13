import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chapter.dart';
import '../models/genre.dart';
import '../models/manga.dart';
import 'auth_service.dart';

/// HTTP client for the optional ASP.NET Core API.
/// If the local backend is stopped, callers can fall back to the existing app SQLite database.
class BackendApiService {
  BackendApiService._();
  static final BackendApiService instance = BackendApiService._();

  static const Duration _timeout = Duration(seconds: 3);
  DateTime? _retryAfter;
  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5080/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5080/api';
      default:
        return 'http://localhost:5080/api';
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-User-Role': AuthService.instance.currentUser.role.name,
      };

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return null;
    final uri = Uri.parse('$_baseUrl$path');
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: _headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(_timeout);
          break;
        case 'PUT':
          response = await http.put(uri, headers: _headers, body: jsonEncode(body)).timeout(_timeout);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: _headers, body: jsonEncode(body)).timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: _headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Backend trả về lỗi ${response.statusCode}.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) message = decoded['message'] as String;
        } catch (_) {}
        throw BackendRequestException(message);
      }
      _retryAfter = null;
      if (response.statusCode == 204 || response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on http.ClientException {
      _retryAfter = DateTime.now().add(const Duration(seconds: 10));
      return null;
    } on TimeoutException {
      _retryAfter = DateTime.now().add(const Duration(seconds: 10));
      return null;
    }
  }

  Future<List<Manga>?> getMangas() async {
    final data = await _request('GET', '/mangas?includeHidden=true');
    if (data == null) return null;
    return (data as List).map((item) => Manga.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> addManga(Manga manga) async { await _request('POST', '/mangas', body: manga.toJson()); }
  Future<void> updateManga(Manga manga) async { await _request('PUT', '/mangas/${Uri.encodeComponent(manga.id)}', body: manga.toJson()); }
  Future<void> deleteManga(String id) async { await _request('DELETE', '/mangas/${Uri.encodeComponent(id)}'); }

  Future<void> setMangaHidden(String id, bool hidden) async {
    await _request('PATCH', '/mangas/${Uri.encodeComponent(id)}/visibility', body: {'hidden': hidden});
  }

  Future<void> setFavorite(String id, bool isFavorite) async {
    await _request('PATCH', '/mangas/${Uri.encodeComponent(id)}/favorite', body: {'isFavorite': isFavorite});
  }

  Future<void> setProgress(String id, int currentChapter) async {
    await _request('PATCH', '/mangas/${Uri.encodeComponent(id)}/progress', body: {'currentChapter': currentChapter});
  }

  Future<List<Genre>?> getGenres() async {
    final data = await _request('GET', '/genres');
    if (data == null) return null;
    return (data as List).map((item) => Genre.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> createGenre(String id, String name) async {
    await _request('POST', '/genres', body: {'id': id, 'name': name});
  }
  Future<void> renameGenre(String id, String name) async {
    await _request('PUT', '/genres/${Uri.encodeComponent(id)}', body: {'name': name});
  }
  Future<void> deleteGenre(String id) async { await _request('DELETE', '/genres/${Uri.encodeComponent(id)}'); }

  Future<List<Chapter>?> getChapters(String mangaId) async {
    final data = await _request('GET', '/mangas/${Uri.encodeComponent(mangaId)}/chapters');
    if (data == null) return null;
    return (data as List).map((item) => Chapter.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }
}

class BackendRequestException implements Exception {
  final String message;
  const BackendRequestException(this.message);
  @override
  String toString() => message;
}
