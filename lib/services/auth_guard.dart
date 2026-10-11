import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

class AuthGuard {
  /// Kiểm tra quyền của người dùng trước khi thực hiện hành động
  /// [requiredRole]: Role tối thiểu cần có
  /// Nếu là Guest -> Bắt buộc đăng ký / đăng nhập
  /// Nếu role không đủ -> Báo lỗi phân quyền
  static Future<bool> checkPermission(
    BuildContext context, {
    required String featureName,
    UserRole minRole = UserRole.reader,
  }) async {
    final auth = AuthService.instance;
    final currentUser = auth.currentUser;

    // 1. Nếu là Guest -> Bắt buộc đăng nhập / đăng ký
    if (auth.isGuest) {
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E212D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_person_rounded, color: Color(0xFFA29BFE), size: 28),
              SizedBox(width: 10),
              Text(
                'Yêu cầu Đăng nhập',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tính năng "$featureName" là tính năng chuyên sâu của hệ thống.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFA29BFE), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn cần đăng ký hoặc đăng nhập tài khoản (tối thiểu vai trò ${minRole.label}) để sử dụng.',
                        style: const TextStyle(color: Color(0xFFA29BFE), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Đăng nhập / Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (res == true && context.mounted) {
                  // Đã đăng nhập, kiểm tra lại quyền
                  return;
                }
              },
            ),
          ],
        ),
      );

      // Kiểm tra lại sau khi mở màn hình login
      if (auth.isLoggedIn) {
        return _hasRolePermission(auth.currentUser.role, minRole);
      }
      return false;
    }

    // 2. Nếu đã đăng nhập nhưng role không đủ thẩm quyền
    if (!_hasRolePermission(currentUser.role, minRole)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD63031),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.gpp_bad_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bạn không có quyền "$featureName". Cần quyền tối thiểu: ${minRole.label} (Bạn là: ${currentUser.role.label})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// So sánh cấp bậc phân quyền: admin > staff > reader > guest
  static bool _hasRolePermission(UserRole userRole, UserRole requiredRole) {
    final hierarchy = {
      UserRole.guest: 0,
      UserRole.reader: 1,
      UserRole.staff: 2,
      UserRole.admin: 3,
    };

    final userLevel = hierarchy[userRole] ?? 0;
    final requiredLevel = hierarchy[requiredRole] ?? 0;
    return userLevel >= requiredLevel;
  }
}
