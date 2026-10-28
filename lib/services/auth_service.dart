import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'wallet_service.dart';
import 'daily_check_in_service.dart';

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
        _currentUser = _allUsers.firstWhere(
          (u) => u.id == savedUserId && u.isActive,
        );
      } catch (_) {
        _currentUser = AppUser.guest;
      }
    } else {
      _currentUser = AppUser.guest;
    }

    if (!_currentUser.isGuest) {
      await WalletService.instance.loadWallet(_currentUser.id);
      try {
        await WalletService.instance.recoverServerPayments(_currentUser);
      } catch (_) {}
      await DailyCheckInService.instance.loadForUser(_currentUser.id);
    }

    notifyListeners();
  }

  /// Đăng nhập
  Future<({bool success, String message})> login(
    String username,
    String password,
  ) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return (
        success: false,
        message: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.',
      );
    }

    final user = _allUsers.cast<AppUser?>().firstWhere(
      (u) => u?.username.toLowerCase() == cleanUsername,
      orElse: () => null,
    );

    if (user == null) {
      return (
        success: false,
        message: 'Tài khoản không tồn tại. Vui lòng đăng ký!',
      );
    }

    if (!user.isActive) {
      return (
        success: false,
        message:
            'Tài khoản này đã bị vô hiệu hoá. Vui lòng liên hệ quản trị viên.',
      );
    }

    if (user.password != cleanPassword) {
      return (
        success: false,
        message: 'Mật khẩu không chính xác. Vui lòng thử lại!',
      );
    }

    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, user.id);

    // Load ví và thông tin điểm danh của user vừa đăng nhập
    await WalletService.instance.loadWallet(user.id);
    // Reconcile all server-confirmed payment receipts before the app renders
    // the wallet, so coins are visible immediately after login.
    try {
      await WalletService.instance.recoverServerPayments(user);
    } catch (_) {
      // Keep the locally cached wallet available when the payment backend is offline.
    }
    await DailyCheckInService.instance.loadForUser(user.id);

    notifyListeners();

    return (
      success: true,
      message: 'Đăng nhập thành công với vai trò ${user.role.label}!',
    );
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

    if (cleanUsername.isEmpty ||
        cleanDisplayName.isEmpty ||
        cleanPassword.isEmpty) {
      return (
        success: false,
        message: 'Vui lòng điền đầy đủ các thông tin bắt buộc.',
      );
    }

    if (cleanUsername.length < 3) {
      return (
        success: false,
        message: 'Tên đăng nhập phải có ít nhất 3 ký tự.',
      );
    }

    if (cleanPassword.length < 4) {
      return (success: false, message: 'Mật khẩu phải có ít nhất 4 ký tự.');
    }

    final exists = _allUsers.any(
      (u) => u.username.toLowerCase() == cleanUsername,
    );
    if (exists) {
      return (
        success: false,
        message: 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác!',
      );
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

    // Tạo ví và khởi tạo điểm danh cho user mới
    await WalletService.instance.loadWallet(newUser.id);
    await DailyCheckInService.instance.loadForUser(newUser.id);

    notifyListeners();

    return (
      success: true,
      message: 'Đăng ký thành công! Chào mừng độc giả ${newUser.displayName}!',
    );
  }

  /// Đăng xuất khỏi hệ thống -> trở về Guest
  Future<void> logout() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    WalletService.instance.clearCache();
    DailyCheckInService.instance.clearCache();
    notifyListeners();
  }

  /// Tiếp tục trải nghiệm với tư cách Khách
  Future<void> continueAsGuest() async {
    _currentUser = AppUser.guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    WalletService.instance.clearCache();
    DailyCheckInService.instance.clearCache();
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

  /// Xóa / vô hiệu hoá user (Admin, UC-42):
  /// - Không xóa chính mình
  /// - Giữ lại Admin cuối cùng (chỉ xét tài khoản đang hoạt động)
  /// - Mặc định vô hiệu hoá để giữ ví, giao dịch, lịch sử mua
  ///   theo tiêu chí nghiệm thu; chỉ xóa hẳn khi không còn dữ liệu liên quan.
  Future<({bool success, String message, bool deactivated})> deleteUser(
    String userId, {
    bool hardDelete = false,
  }) async {
    if (!_currentUser.role.canManageUsers) {
      return (
        success: false,
        message: 'Chỉ quản trị viên mới được vô hiệu hoá tài khoản.',
        deactivated: false,
      );
    }
    if (_currentUser.id == userId) {
      return (
        success: false,
        message: 'Không thể tự xóa tài khoản đang đăng nhập!',
        deactivated: false,
      );
    }

    final userIndex = _allUsers.indexWhere((u) => u.id == userId);
    if (userIndex == -1) {
      return (
        success: false,
        message: 'Không tìm thấy tài khoản cần xóa.',
        deactivated: false,
      );
    }
    final targetUser = _allUsers[userIndex];

    if (targetUser.role == UserRole.admin) {
      final adminCount = _allUsers
          .where((u) => u.role == UserRole.admin && u.isActive)
          .length;
      if (targetUser.isActive && adminCount <= 1) {
        return (
          success: false,
          message:
              'Không thể xóa Admin cuối cùng của hệ thống! Hãy nâng cấp một tài khoản khác lên Admin trước.',
          deactivated: false,
        );
      }
    }

    final hasHistory = await _hasUserFinancialData(userId);
    if (!hardDelete || hasHistory) {
      await DatabaseHelper.instance.deactivateUser(userId);
      _allUsers[userIndex] = targetUser.copyWith(isActive: false);
      notifyListeners();
      return (
        success: true,
        message:
            'Đã vô hiệu hoá tài khoản @${targetUser.username}. Ví, giao dịch và lịch sử mua được giữ nguyên.',
        deactivated: true,
      );
    }

    await DatabaseHelper.instance.deleteUser(userId);
    _allUsers.removeAt(userIndex);
    notifyListeners();

    return (
      success: true,
      message:
          'Đã xóa tài khoản @${targetUser.username} (${targetUser.displayName}).',
      deactivated: false,
    );
  }

  Future<bool> hasUserFinancialData(String userId) =>
      _hasUserFinancialData(userId);

  Future<bool> _hasUserFinancialData(String userId) async {
    final db = DatabaseHelper.instance;
    final wallet = await db.getWalletByUserId(userId);
    if (wallet != null &&
        (wallet.balance != 0 ||
            wallet.totalEarned != 0 ||
            wallet.totalSpent != 0)) {
      return true;
    }
    final transactions = await db.getTransactionsByUserId(userId, limit: 1);
    if (transactions.isNotEmpty) return true;
    final purchased = await db.getPurchasedChapterIds(userId);
    return purchased.isNotEmpty;
  }

  Future<({bool success, String message})> reactivateUser(String userId) async {
    final index = _allUsers.indexWhere((u) => u.id == userId);
    if (index == -1) {
      return (success: false, message: 'Không tìm thấy tài khoản.');
    }
    await DatabaseHelper.instance.reactivateUser(userId);
    _allUsers[index] = _allUsers[index].copyWith(isActive: true);
    notifyListeners();
    return (
      success: true,
      message: 'Đã kích hoạt lại tài khoản @${_allUsers[index].username}.',
    );
  }

  /// Cập nhật tên hiển thị cá nhân (Edit Profile)
  Future<({bool success, String message})> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    if (isGuest) {
      return (success: false, message: 'Bạn chưa đăng nhập tài khoản!');
    }

    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      return (success: false, message: 'Tên hiển thị không được để trống.');
    }

    if (cleanName.length < 2) {
      return (success: false, message: 'Tên hiển thị phải có ít nhất 2 ký tự.');
    }

    if (cleanName.length > 50) {
      return (
        success: false,
        message: 'Tên hiển thị không được vượt quá 50 ký tự.',
      );
    }

    await DatabaseHelper.instance.updateUserProfile(
      id: _currentUser.id,
      displayName: cleanName,
      avatarUrl: avatarUrl,
    );

    final updated = _currentUser.copyWith(
      displayName: cleanName,
      avatarUrl: avatarUrl ?? _currentUser.avatarUrl,
    );
    _currentUser = updated;

    final index = _allUsers.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _allUsers[index] = updated;
    }

    notifyListeners();
    return (success: true, message: 'Cập nhật thông tin hồ sơ thành công!');
  }

  /// Cập nhật ảnh đại diện cá nhân (Upload / Change Avatar)
  Future<({bool success, String message})> updateAvatar(
    String? avatarUrl,
  ) async {
    if (isGuest) {
      return (success: false, message: 'Bạn chưa đăng nhập tài khoản!');
    }

    await DatabaseHelper.instance.updateUserAvatar(_currentUser.id, avatarUrl);

    final updated = _currentUser.copyWith(avatarUrl: avatarUrl);
    _currentUser = updated;

    final index = _allUsers.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _allUsers[index] = updated;
    }

    notifyListeners();
    return (
      success: true,
      message: avatarUrl != null && avatarUrl.isNotEmpty
          ? 'Đổi ảnh đại diện thành công!'
          : 'Đã khôi phục ảnh đại diện mặc định.',
    );
  }

  /// Đổi mật khẩu cá nhân (Change Password)
  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isGuest) {
      return (success: false, message: 'Bạn chưa đăng nhập tài khoản!');
    }

    final cleanCurrent = currentPassword.trim();
    final cleanNew = newPassword.trim();

    if (cleanCurrent.isEmpty || cleanNew.isEmpty) {
      return (
        success: false,
        message: 'Vui lòng nhập đầy đủ mật khẩu hiện tại và mật khẩu mới.',
      );
    }

    if (_currentUser.password != cleanCurrent) {
      return (
        success: false,
        message: 'Mật khẩu hiện tại không chính xác. Vui lòng kiểm tra lại!',
      );
    }

    if (cleanNew.length < 4) {
      return (success: false, message: 'Mật khẩu mới phải có ít nhất 4 ký tự.');
    }

    if (cleanNew == cleanCurrent) {
      return (
        success: false,
        message: 'Mật khẩu mới không được trùng với mật khẩu hiện tại.',
      );
    }

    await DatabaseHelper.instance.updateUserPassword(
      _currentUser.username,
      cleanNew,
    );

    final updated = _currentUser.copyWith(password: cleanNew);
    _currentUser = updated;

    final index = _allUsers.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _allUsers[index] = updated;
    }

    notifyListeners();
    return (success: true, message: 'Đổi mật khẩu thành công!');
  }

  /// Người dùng tự xóa tài khoản của mình (User Delete Account)
  /// - Kiểm tra xác nhận mật khẩu
  /// - Nếu là Admin cuối cùng -> Ngăn chặn xóa
  /// - Xóa xong tự động đăng xuất và chuyển về Guest
  Future<({bool success, String message})> deleteCurrentAccount({
    required String confirmPassword,
  }) async {
    if (isGuest) {
      return (success: false, message: 'Tài khoản khách không thể xóa.');
    }

    final cleanPassword = confirmPassword.trim();
    if (cleanPassword.isEmpty) {
      return (
        success: false,
        message: 'Vui lòng nhập mật khẩu xác nhận để xóa tài khoản.',
      );
    }

    if (_currentUser.password != cleanPassword) {
      return (success: false, message: 'Mật khẩu xác nhận không chính xác!');
    }

    // Bảo vệ Admin cuối cùng
    if (_currentUser.role == UserRole.admin) {
      final adminCount = _allUsers
          .where((u) => u.role == UserRole.admin && u.isActive)
          .length;
      if (adminCount <= 1) {
        return (
          success: false,
          message:
              'Bạn là Quản trị viên (Admin) duy nhất của hệ thống! Không thể tự xóa tài khoản. Hãy chỉ định một tài khoản khác làm Admin trước.',
        );
      }
    }

    final targetId = _currentUser.id;
    final targetName = _currentUser.displayName;

    final hasHistory = await _hasUserFinancialData(targetId);
    if (hasHistory) {
      await DatabaseHelper.instance.deactivateUser(targetId);
    } else {
      await DatabaseHelper.instance.deleteUser(targetId);
    }

    _allUsers.removeWhere((u) => u.id == targetId);

    // Đăng xuất và dọn dẹp phiên
    await logout();

    return (
      success: true,
      message: hasHistory
          ? 'Tài khoản "$targetName" đã được vô hiệu hoá. Lịch sử ví và giao dịch được giữ lại.'
          : 'Tài khoản "$targetName" đã được xóa khỏi hệ thống.',
    );
  }

  // Thông tin phiên reset mật khẩu tạm thời
  String? _resetUsername;
  String? _resetOtp;
  DateTime? _resetOtpExpiry;

  /// 1. Yêu cầu tạo mã OTP đặt lại mật khẩu cho tài khoản
  Future<({bool success, String message, String? otp})> requestPasswordReset(
    String username,
  ) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return (
        success: false,
        message: 'Vui lòng nhập tên đăng nhập.',
        otp: null,
      );
    }

    final user = _allUsers.cast<AppUser?>().firstWhere(
      (u) => u?.username.toLowerCase() == cleanUsername,
      orElse: () => null,
    );

    if (user == null) {
      return (
        success: false,
        message:
            'Tài khoản "$username" không tồn tại trong hệ thống. Vui lòng kiểm tra lại!',
        otp: null,
      );
    }
    if (!user.isActive) {
      return (
        success: false,
        message: 'Tài khoản đã bị vô hiệu hoá, không thể đặt lại mật khẩu.',
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
      return (
        success: false,
        message: 'Vui lòng nhập đầy đủ các trường thông tin.',
      );
    }

    if (cleanNewPassword.length < 4) {
      return (success: false, message: 'Mật khẩu mới phải có ít nhất 4 ký tự.');
    }

    final resetUser = _allUsers.cast<AppUser?>().firstWhere(
      (u) => u?.username.toLowerCase() == cleanUsername,
      orElse: () => null,
    );
    if (resetUser != null && !resetUser.isActive) {
      return (
        success: false,
        message: 'Tài khoản đã bị vô hiệu hoá, không thể đặt lại mật khẩu.',
      );
    }

    if (_resetUsername != cleanUsername || _resetOtp != cleanOtp) {
      return (
        success: false,
        message:
            'Mã xác thực OTP không chính xác hoặc tên tài khoản không khớp!',
      );
    }

    if (_resetOtpExpiry != null && DateTime.now().isAfter(_resetOtpExpiry!)) {
      return (
        success: false,
        message:
            'Mã xác thực OTP đã hết hạn (sau 5 phút). Vui lòng yêu cầu mã mới!',
      );
    }

    final index = _allUsers.indexWhere(
      (u) => u.username.toLowerCase() == cleanUsername,
    );
    if (index == -1) {
      return (success: false, message: 'Không tìm thấy tài khoản tương ứng.');
    }

    // Cập nhật mật khẩu trong SQLite
    await DatabaseHelper.instance.updateUserPassword(
      cleanUsername,
      cleanNewPassword,
    );

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
    return (
      success: true,
      message:
          'Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới.',
    );
  }
}
