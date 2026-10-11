import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  static const String _usersKey = 'manga_vault_users_list_v1';
  static const String _currentSessionKey = 'manga_vault_current_session_v1';

  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  AppUser _currentUser = AppUser.guest;
  AppUser get currentUser => _currentUser;
  bool get isGuest => _currentUser.isGuest;
  bool get isLoggedIn => !_currentUser.isGuest;

  List<AppUser> _allUsers = [];

  // Danh sách tài khoản mặc định để thử nghiệm
  final List<AppUser> _seedUsers = const [
    AppUser(
      id: 'admin_1',
      username: 'admin',
      displayName: 'Quản Trị Viên (Admin)',
      password: 'admin123',
      role: UserRole.admin,
    ),
    AppUser(
      id: 'staff_1',
      username: 'staff',
      displayName: 'Biên Tập Viên (Staff)',
      password: 'staff123',
      role: UserRole.staff,
    ),
    AppUser(
      id: 'reader_1',
      username: 'reader',
      displayName: 'Độc Giả VIP (Reader)',
      password: 'reader123',
      role: UserRole.reader,
    ),
  ];

  /// Khởi tạo và nạp dữ liệu phiên đăng nhập
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Nạp danh sách người dùng
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null && usersJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(usersJson);
      _allUsers = decoded.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      _allUsers = List.from(_seedUsers);
      await _saveUsersToDisk();
    }

    // 2. Nạp phiên đăng nhập trước đó (nếu có)
    final savedUserId = prefs.getString(_currentSessionKey);
    if (savedUserId != null && savedUserId.isNotEmpty) {
      try {
        _currentUser = _allUsers.firstWhere((u) => u.id == savedUserId);
      } catch (_) {
        _currentUser = AppUser.guest;
      }
    } else {
      _currentUser = AppUser.guest;
    }

    notifyListeners();
  }

  /// Đăng nhập
  Future<({bool success, String message})> login(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return (success: false, message: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.');
    }

    final user = _allUsers.cast<AppUser?>().firstWhere(
          (u) => u?.username.toLowerCase() == cleanUsername,
          orElse: () => null,
        );

    if (user == null) {
      return (success: false, message: 'Tài khoản không tồn tại. Vui lòng đăng ký!');
    }

    if (user.password != cleanPassword) {
      return (success: false, message: 'Mật khẩu không chính xác. Vui lòng thử lại!');
    }

    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, user.id);
    notifyListeners();

    return (success: true, message: 'Đăng nhập thành công với vai trò ${user.role.label}!');
  }

  /// Đăng ký tài khoản mới (Mặc định vai trò là Reader)
  Future<({bool success, String message})> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanDisplayName = displayName.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanDisplayName.isEmpty || cleanPassword.isEmpty) {
      return (success: false, message: 'Vui lòng điền đầy đủ các thông tin bắt buộc.');
    }

    if (cleanUsername.length < 3) {
      return (success: false, message: 'Tên đăng nhập phải có ít nhất 3 ký tự.');
    }

    if (cleanPassword.length < 4) {
      return (success: false, message: 'Mật khẩu phải có ít nhất 4 ký tự.');
    }

    final exists = _allUsers.any((u) => u.username.toLowerCase() == cleanUsername);
    if (exists) {
      return (success: false, message: 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác!');
    }

    final newUser = AppUser(
      id: const Uuid().v4(),
      username: cleanUsername,
      displayName: cleanDisplayName,
      password: cleanPassword,
      role: UserRole.reader, // Mặc định đăng ký mới là Reader
    );

    _allUsers.add(newUser);
    await _saveUsersToDisk();

    // Tự động đăng nhập luôn sau khi đăng ký
    _currentUser = newUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, newUser.id);
    notifyListeners();

    return (success: true, message: 'Đăng ký thành công! Chào mừng độc giả ${newUser.displayName}!');
  }

  /// Đăng xuất khỏi hệ thống -> trở về Guest
  Future<void> logout() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    notifyListeners();
  }

  /// Tiếp tục trải nghiệm với tư cách Khách
  Future<void> continueAsGuest() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    notifyListeners();
  }

  /// Lấy toàn bộ danh sách tài khoản (cho Admin)
  List<AppUser> getAllUsers() {
    return List.unmodifiable(_allUsers);
  }

  /// Thay đổi quyền của user (chỉ Admin)
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    final index = _allUsers.indexWhere((u) => u.id == userId);
    if (index == -1) return false;

    final updated = _allUsers[index].copyWith(role: newRole);
    _allUsers[index] = updated;

    if (_currentUser.id == userId) {
      _currentUser = updated;
    }

    await _saveUsersToDisk();
    notifyListeners();
    return true;
  }

  /// Xóa user (chỉ Admin, không được xóa chính mình)
  Future<({bool success, String message})> deleteUser(String userId) async {
    if (_currentUser.id == userId) {
      return (success: false, message: 'Không thể tự xóa tài khoản đang đăng nhập!');
    }

    _allUsers.removeWhere((u) => u.id == userId);
    await _saveUsersToDisk();
    notifyListeners();
    return (success: true, message: 'Đã xóa người dùng thành công.');
  }

  // Thông tin phiên reset mật khẩu tạm thời
  String? _resetUsername;
  String? _resetOtp;
  DateTime? _resetOtpExpiry;

  /// 1. Yêu cầu tạo mã OTP đặt lại mật khẩu cho tài khoản
  Future<({bool success, String message, String? otp})> requestPasswordReset(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return (success: false, message: 'Vui lòng nhập tên đăng nhập.', otp: null);
    }

    final user = _allUsers.cast<AppUser?>().firstWhere(
      (u) => u?.username.toLowerCase() == cleanUsername,
      orElse: () => null,
    );

    if (user == null) {
      return (
        success: false,
        message: 'Tài khoản "$username" không tồn tại trong hệ thống. Vui lòng kiểm tra lại!',
        otp: null,
      );
    }

    // Tạo mã OTP 6 số ngẫu nhiên
    final random = Random();
    final otp = (100000 + random.nextInt(900000)).toString();
    _resetUsername = cleanUsername;
    _resetOtp = otp;
    _resetOtpExpiry = DateTime.now().add(const Duration(minutes: 5));

    return (
      success: true,
      message: 'Mã xác thực OTP đã được tạo cho tài khoản ${user.displayName}.',
      otp: otp,
    );
  }

  /// 2. Xác thực OTP và đặt lại mật khẩu mới
  Future<({bool success, String message})> verifyOtpAndResetPassword({
    required String username,
    required String otp,
    required String newPassword,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanOtp = otp.trim();
    final cleanNewPassword = newPassword.trim();

    if (cleanUsername.isEmpty || cleanOtp.isEmpty || cleanNewPassword.isEmpty) {
      return (success: false, message: 'Vui lòng nhập đầy đủ các trường thông tin.');
    }

    if (cleanNewPassword.length < 4) {
      return (success: false, message: 'Mật khẩu mới phải có ít nhất 4 ký tự.');
    }

    if (_resetUsername != cleanUsername || _resetOtp != cleanOtp) {
      return (success: false, message: 'Mã xác thực OTP không chính xác hoặc tên tài khoản không khớp!');
    }

    if (_resetOtpExpiry != null && DateTime.now().isAfter(_resetOtpExpiry!)) {
      return (success: false, message: 'Mã xác thực OTP đã hết hạn (sau 5 phút). Vui lòng yêu cầu mã mới!');
    }

    final index = _allUsers.indexWhere((u) => u.username.toLowerCase() == cleanUsername);
    if (index == -1) {
      return (success: false, message: 'Không tìm thấy tài khoản tương ứng.');
    }

    // Cập nhật mật khẩu mới
    final updatedUser = _allUsers[index].copyWith(password: cleanNewPassword);
    _allUsers[index] = updatedUser;

    if (_currentUser.username.toLowerCase() == cleanUsername) {
      _currentUser = updatedUser;
    }

    await _saveUsersToDisk();

    // Dọn dẹp phiên reset sau khi hoàn tất
    _resetUsername = null;
    _resetOtp = null;
    _resetOtpExpiry = null;

    notifyListeners();
    return (success: true, message: 'Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới.');
  }

  /// Lưu danh sách người dùng vào SharedPreferences
  Future<void> _saveUsersToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_allUsers.map((u) => u.toJson()).toList());
    await prefs.setString(_usersKey, jsonStr);
  }
}
