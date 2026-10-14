import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'wallet_service.dart';

class AuthService extends ChangeNotifier {
  static const String _currentSessionKey = 'manga_vault_current_session_v1';

  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  AppUser _currentUser = AppUser.guest;
  AppUser get currentUser => _currentUser;
  bool get isGuest => _currentUser.isGuest;
  bool get isLoggedIn => !_currentUser.isGuest;

  List<AppUser> _allUsers = [];

  /// Khởi tạo và nạp dữ liệu phiên đăng nhập từ SQLite & SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Nạp danh sách người dùng từ SQLite
    _allUsers = await DatabaseHelper.instance.getAllUsers();

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

    // Load ví của user vừa đăng nhập
    await WalletService.instance.loadWallet(user.id);
    // Reconcile all server-confirmed payment receipts before the app renders
    // the wallet, so coins are visible immediately after login.
    try {
      await WalletService.instance.recoverServerPayments(user);
    } catch (_) {
      // Keep the locally cached wallet available when the payment backend is offline.
    }

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

    // Lưu vào SQLite
    await DatabaseHelper.instance.insertUser(newUser);
    _allUsers.add(newUser);

    // Tự động đăng nhập luôn sau khi đăng ký
    _currentUser = newUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, newUser.id);

    // Tạo ví cho user mới
    await WalletService.instance.loadWallet(newUser.id);

    notifyListeners();

    return (success: true, message: 'Đăng ký thành công! Chào mừng độc giả ${newUser.displayName}!');
  }

  /// Đăng xuất khỏi hệ thống -> trở về Guest
  Future<void> logout() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    WalletService.instance.clearCache();
    notifyListeners();
  }

  /// Tiếp tục trải nghiệm với tư cách Khách
  Future<void> continueAsGuest() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    WalletService.instance.clearCache();
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

    await DatabaseHelper.instance.updateUserRole(userId, newRole);

    final updated = _allUsers[index].copyWith(role: newRole);
    _allUsers[index] = updated;

    if (_currentUser.id == userId) {
      _currentUser = updated;
    }

    notifyListeners();
    return true;
  }

  /// Xóa user (Admin) - Level Complex:
  /// - Không xóa chính mình
  /// - Không xóa Admin cuối cùng (phải còn ít nhất 1 Admin trong hệ thống)
  /// - Xóa cascade: ví, giao dịch của user
  /// - Trả về thông báo chi tiết
  Future<({bool success, String message})> deleteUser(String userId) async {
    // 1. Không cho xóa chính mình
    if (_currentUser.id == userId) {
      return (success: false, message: 'Không thể tự xóa tài khoản đang đăng nhập!');
    }

    final userIndex = _allUsers.indexWhere((u) => u.id == userId);
    if (userIndex == -1) {
      return (success: false, message: 'Không tìm thấy tài khoản cần xóa.');
    }
    final targetUser = _allUsers[userIndex];

    // 2. Bảo vệ Admin cuối cùng: nếu user bị xóa là Admin, phải còn ít nhất 1 Admin khác
    if (targetUser.role == UserRole.admin) {
      final adminCount = _allUsers.where((u) => u.role == UserRole.admin).length;
      if (adminCount <= 1) {
        return (
          success: false,
          message: 'Không thể xóa Admin cuối cùng của hệ thống! Hãy nâng cấp một tài khoản khác lên Admin trước.',
        );
      }
    }

    // 3. Xóa cascade: ví & giao dịch của user (DatabaseHelper chưa có cascade riêng
    //    cho wallet/transaction, nhưng FOREIGN KEY ON DELETE CASCADE sẽ tự xóa khi user bị xóa)
    await DatabaseHelper.instance.deleteUser(userId);
    _allUsers.removeAt(userIndex);
    notifyListeners();

    return (
      success: true,
      message: 'Đã xóa tài khoản @${targetUser.username} (${targetUser.displayName}) và toàn bộ ví, giao dịch liên quan.',
    );
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

    // Cập nhật mật khẩu trong SQLite
    await DatabaseHelper.instance.updateUserPassword(cleanUsername, cleanNewPassword);

    final updatedUser = _allUsers[index].copyWith(password: cleanNewPassword);
    _allUsers[index] = updatedUser;

    if (_currentUser.username.toLowerCase() == cleanUsername) {
      _currentUser = updatedUser;
    }

    // Dọn dẹp phiên reset sau khi hoàn tất
    _resetUsername = null;
    _resetOtp = null;
    _resetOtpExpiry = null;

    notifyListeners();
    return (success: true, message: 'Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới.');
  }
}
