import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/wallet_service.dart';
import '../widgets/profile_dialogs.dart';
import 'coin_package_management_screen.dart';
import 'form_screen.dart';
import 'user_management_screen.dart';
import 'wallet_screen.dart';
import '../services/daily_check_in_service.dart';
import '../widgets/daily_check_in_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService.instance;
  final WalletService _wallet = WalletService.instance;
  final ThemeService _theme = ThemeService.instance;
  final DailyCheckInService _dailyCheckIn = DailyCheckInService.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onStateChanged);
    _wallet.addListener(_onStateChanged);
    _theme.addListener(_onStateChanged);
    _dailyCheckIn.addListener(_onStateChanged);
    final user = _auth.currentUser;
    if (!user.isGuest) {
      _dailyCheckIn.loadForUser(user.id);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onStateChanged);
    _wallet.removeListener(_onStateChanged);
    _theme.removeListener(_onStateChanged);
    _dailyCheckIn.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatCoins(int n) {
    if (n < 1000) return n.toString();
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = _auth.currentUser;

    // Nếu là Guest (hoặc vừa tự xóa tài khoản), tự động đóng màn hình Profile
    if (currentUser.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ Của Tôi'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Chuyển sang Chế độ Sáng' : 'Chuyển sang Chế độ Tối',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF6C5CE7),
            ),
            onPressed: () => _theme.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // ============================================================
                // HEADER THÔNG TIN NGƯỜI DÙNG & AVATAR
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar với nút Camera chọn ảnh
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [currentUser.role.color, currentUser.role.color.withValues(alpha: 0.5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: currentUser.role.color.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Container(
                                color: isDark ? const Color(0xFF161924) : Colors.white,
                                child: (currentUser.avatarUrl != null && currentUser.avatarUrl!.isNotEmpty)
                                    ? Image.network(
                                        currentUser.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(
                                          currentUser.role.icon,
                                          size: 52,
                                          color: currentUser.role.color,
                                        ),
                                      )
                                    : Icon(
                                        currentUser.role.icon,
                                        size: 52,
                                        color: currentUser.role.color,
                                      ),
                              ),
                            ),
                          ),
                          // Nút Camera chỉnh sửa avatar
                          InkWell(
                            onTap: () => AvatarPickerDialog.show(context, currentUser),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tên hiển thị
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              currentUser.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6C5CE7)),
                            tooltip: 'Đổi tên hiển thị',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => EditProfileDialog.show(context, currentUser),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Username @
                      Text(
                        '@${currentUser.username}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 10),

                      // Badge Vai trò (Role)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: currentUser.role.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: currentUser.role.color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(currentUser.role.icon, size: 16, color: currentUser.role.color),
                            const SizedBox(width: 6),
                            Text(
                              'Vai trò: ${currentUser.role.label}',
                              style: TextStyle(
                                color: currentUser.role.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ============================================================
                // THỐNG KÊ VÍ & HOẠT ĐỘNG
                // ============================================================
                if (currentUser.role.canAccessWallet) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1F2438), const Color(0xFF282F48)]
                            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB300), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Số dư ví hiện tại',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatCoins(_wallet.balance)} Coins',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Nạp Thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WalletScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // ============================================================
                // THẺ ĐIỂM DANH HÀNG NGÀY (DAILY CHECK-IN)
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF261D3B), const Color(0xFF1B192E)]
                          : [const Color(0xFFFBF0FF), const Color(0xFFF3E8FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Điểm Danh Hàng Ngày',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                if (!_dailyCheckIn.hasCheckedInToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CHƯA NHẬN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dailyCheckIn.hasCheckedInToday
                                  ? 'Đã nhận hôm nay (Chuỗi: ${_dailyCheckIn.currentStreak} ngày)'
                                  : 'Chuỗi: ${_dailyCheckIn.currentStreak} ngày • Nhận ngay quà hôm nay!',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dailyCheckIn.hasCheckedInToday
                              ? Colors.grey.withValues(alpha: 0.3)
                              : const Color(0xFFFFB800),
                          foregroundColor: _dailyCheckIn.hasCheckedInToday
                              ? Colors.white70
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => DailyCheckInDialog.show(context),
                        child: Text(
                          _dailyCheckIn.hasCheckedInToday ? 'Xem Quà' : 'Điểm Danh',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ============================================================
                // CÁC THAO TÁC TÀI KHOẢN (ACCOUNT ACTIONS)
                // ============================================================
                Text(
                  'CÀI ĐẶT TÀI KHOẢN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_rounded, color: Color(0xFF6C5CE7)),
                        title: const Text('Chỉnh sửa tên hiển thị'),
                        subtitle: Text(currentUser.displayName, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => EditProfileDialog.show(context, currentUser),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.account_circle_rounded, color: Color(0xFF00B894)),
                        title: const Text('Đổi ảnh đại diện (Avatar)'),
                        subtitle: const Text('Chọn mẫu Manga hoặc link ảnh', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => AvatarPickerDialog.show(context, currentUser),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFFE17055)),
                        title: const Text('Đổi mật khẩu'),
                        subtitle: const Text('Cập nhật mật khẩu bảo mật mới', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => ChangePasswordDialog.show(context, currentUser),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ============================================================
                // TIỆN ÍCH DÀNH RIÊNG THEO VAI TRÒ (ROLE-BASED ACTIONS)
                // ============================================================
                if (currentUser.role == UserRole.admin || currentUser.role == UserRole.staff) ...[
                  Text(
                    'QUẢN TRỊ & BIÊN TẬP HỆ THỐNG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (currentUser.role.canManageUsers) ...[
                          ListTile(
                            leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFE84393)),
                            title: const Text('Quản lý người dùng & phân quyền'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1),
                        ],
                        if (currentUser.role.canManageCoinPackages) ...[
                          ListTile(
                            leading: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB300)),
                            title: const Text('Quản lý gói nạp Coins'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CoinPackageManagementScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1),
                        ],
                        if (currentUser.role.canAddManga)
                          ListTile(
                            leading: const Icon(Icons.post_add_rounded, color: Color(0xFF0984E3)),
                            title: const Text('Thêm truyện Manga mới'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MangaFormScreen()),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // ============================================================
                // BẢNG QUYỀN HẠN CỦA VAI TRÒ (PERMISSIONS OVERVIEW)
                // ============================================================
                Text(
                  'QUYỀN HẠN HIỆN TẠI CỦA BẠN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildPermItem('Xem & tìm kiếm truyện Manga', true),
                      _buildPermItem('Lưu truyện yêu thích', currentUser.role.canFavorite),
                      _buildPermItem('Đánh dấu trang (Bookmark) & lưu tiến độ', currentUser.role.canTrackProgress),
                      _buildPermItem('Sử dụng ví Coins & mua chương', currentUser.role.canAccessWallet),
                      _buildPermItem('Thêm truyện mới (Staff / Admin)', currentUser.role.canAddManga),
                      _buildPermItem('Chỉnh sửa truyện & Chapter (Staff)', currentUser.role.canEditManga),
                      _buildPermItem('Xóa truyện (Admin)', currentUser.role.canDeleteManga),
                      _buildPermItem('Quản trị phân quyền người dùng (Admin)', currentUser.role.canManageUsers),
                      _buildPermItem('Quản lý gói nạp Coins (Admin)', currentUser.role.canManageCoinPackages),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ============================================================
                // NÚT ĐĂNG XUẤT
                // ============================================================
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C5CE7),
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Đăng Xuất Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _auth.logout();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Đã đăng xuất khỏi tài khoản.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ============================================================
                // VÙNG NGUY HIỂM (DANGER ZONE): XÓA TÀI KHOẢN
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Xóa vĩnh viễn tài khoản',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hủy tài khoản, xóa ví và toàn bộ dữ liệu cá nhân.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => UserDeleteAccountDialog.show(context, currentUser),
                        child: const Text('Xóa ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermItem(String title, bool allowed) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          Icon(
            allowed ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            size: 16,
            color: allowed ? const Color(0xFF00B894) : Colors.grey.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
