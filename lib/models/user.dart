import 'package:flutter/material.dart';

enum UserRole {
  guest,
  reader,
  staff,
  admin;

  String get label {
    switch (this) {
      case UserRole.guest:
        return 'Khách';
      case UserRole.reader:
        return 'Độc giả';
      case UserRole.staff:
        return 'Nhân viên';
      case UserRole.admin:
        return 'Quản trị viên';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.guest:
        return const Color(0xFF9E9E9E);
      case UserRole.reader:
        return const Color(0xFF00B894);
      case UserRole.staff:
        return const Color(0xFF0984E3);
      case UserRole.admin:
        return const Color(0xFFE84393);
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.guest:
        return Icons.person_outline;
      case UserRole.reader:
        return Icons.menu_book_rounded;
      case UserRole.staff:
        return Icons.edit_note_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  bool get canFavorite => this != UserRole.guest;
  bool get canTrackProgress => this != UserRole.guest;
  bool get canAddManga => this == UserRole.staff || this == UserRole.admin;
  bool get canEditManga => this == UserRole.staff || this == UserRole.admin;
  bool get canCreateChapter => this == UserRole.staff;
  bool get canEditChapter => this == UserRole.staff;
  bool get canDeleteChapter => this == UserRole.staff;
  bool get canDeleteManga => this == UserRole.admin;
  bool get canManageUsers => this == UserRole.admin;
  bool get canAccessWallet => this != UserRole.guest;
  bool get canManageCoinPackages => this == UserRole.admin;
  bool get canPushNotification => this == UserRole.admin || this == UserRole.staff;
}

class AppUser {
  final String id;
  final String username;
  final String displayName;
  final String password;
  final UserRole role;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.password,
    required this.role,
    this.avatarUrl,
  });

  bool get isGuest => role == UserRole.guest;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'password': password,
      'role': role.name,
      'avatarUrl': avatarUrl,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser.fromMap(json);
  }

  /// Chuyển đổi sang Map để lưu vào bảng SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'password': password,
      'role': role.name,
      'avatar_url': avatarUrl,
    };
  }

  /// Khởi tạo đối tượng từ SQLite Map hoặc JSON Map
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      username: map['username'] as String? ?? '',
      displayName: (map['display_name'] ?? map['displayName']) as String? ?? '',
      password: map['password'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.reader,
      ),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl']) as String?,
    );
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? displayName,
    String? password,
    UserRole? role,
    String? avatarUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      password: password ?? this.password,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  static const AppUser guest = AppUser(
    id: 'guest',
    username: 'guest',
    displayName: 'Khách',
    password: '',
    role: UserRole.guest,
    avatarUrl: null,
  );
}
