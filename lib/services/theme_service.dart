import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'manga_vault_theme_mode_v1';
  static final ThemeService instance = ThemeService._internal();
  ThemeService._internal();

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Mặc định là Dark Mode nếu chưa cài đặt
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1017),
      cardColor: const Color(0xFF181B26),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C5CE7),
        surface: Color(0xFF181B26),
        surfaceContainerHighest: Color(0xFF222634),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFA0A5B5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF12141E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerColor: const Color(0xFF262A3B),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E212D),
        selectedColor: const Color(0xFF6C5CE7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F5F9),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6C5CE7),
        surface: Colors.white,
        surfaceContainerHighest: Color(0xFFEBEFF5),
        onSurface: Color(0xFF1A1C24),
        onSurfaceVariant: Color(0xFF636E72),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1C24),
        elevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF1A1C24)),
      ),
      dividerColor: const Color(0xFFE2E5EE),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE9ECEF),
        selectedColor: const Color(0xFF6C5CE7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
    );
  }
}
