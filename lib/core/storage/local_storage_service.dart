import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_exception.dart';

/// Dịch vụ lưu trữ cục bộ bọc SharedPreferences
class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  Future<bool> setString(String key, String value) async {
    try {
      return await _prefs.setString(key, value);
    } catch (e) {
      throw CacheException('Lỗi khi lưu dữ liệu chuỗi vào cache: $e');
    }
  }

  String? getString(String key) {
    try {
      return _prefs.getString(key);
    } catch (e) {
      throw CacheException('Lỗi khi đọc dữ liệu chuỗi từ cache: $e');
    }
  }

  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list) async {
    try {
      final jsonString = jsonEncode(list);
      return await _prefs.setString(key, jsonString);
    } catch (e) {
      throw CacheException('Lỗi khi lưu danh sách JSON: $e');
    }
  }

  List<Map<String, dynamic>>? getJsonList(String key) {
    try {
      final jsonString = _prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      throw CacheException('Lỗi khi đọc danh sách JSON: $e');
    }
  }

  Future<bool> setStringList(String key, List<String> list) async {
    try {
      return await _prefs.setStringList(key, list);
    } catch (e) {
      throw CacheException('Lỗi khi lưu danh sách chuỗi: $e');
    }
  }

  List<String>? getStringList(String key) {
    try {
      return _prefs.getStringList(key);
    } catch (e) {
      throw CacheException('Lỗi khi đọc danh sách chuỗi: $e');
    }
  }

  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  Future<bool> clear() async {
    return await _prefs.clear();
  }
}
