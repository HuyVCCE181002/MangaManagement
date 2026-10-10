import 'package:flutter/material.dart';

/// Bảng màu hiện đại cho ứng dụng Manga Management (Dark / Cyber Anime theme)
class AppColors {
  AppColors._();

  // Primary & Accent Colors
  static const Color primary = Color(0xFF6C5CE7); // Deep Purple
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color secondary = Color(0xFFFF7675); // Vibrant Coral
  static const Color accent = Color(0xFF00CEC9); // Cyber Turquoise

  // Dark Theme Backgrounds
  static const Color background = Color(0xFF0F1016); // Deep space dark
  static const Color surface = Color(0xFF181A24); // Card / Sheet surface
  static const Color surfaceVariant = Color(0xFF222534); // Inner element container
  static const Color surfaceBorder = Color(0xFF2E3248); // Subtle border

  // Light Theme Colors (khi cần chuyển đổi)
  static const Color backgroundLight = Color(0xFFF8F9FD);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceBorderLight = Color(0xFFE2E8F0);

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F2F6);
  static const Color textSecondary = Color(0xFFA4B0BE);
  static const Color textMuted = Color(0xFF747D8C);

  // Status Colors
  static const Color statusOngoing = Color(0xFF2ED573); // Green
  static const Color statusCompleted = Color(0xFF1E90FF); // Blue
  static const Color statusHiatus = Color(0xFFFFA502); // Orange / Warning
  static const Color statusDropped = Color(0xFFFF4757); // Red

  // Functional Colors
  static const Color star = Color(0xFFFFC048);
  static const Color error = Color(0xFFFF4757);
  static const Color success = Color(0xFF2ED573);
  static const Color favorite = Color(0xFFFF4757);
}
