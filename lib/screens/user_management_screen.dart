import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _auth = AuthService.instance;
  late List<AppUser> _users;

  @override
  void initState() {
    super.initState();
    _users = _auth.getAllUsers();
  }

  void _refresh() {
    setState(() {
      _users = _auth.getAllUsers();
    });
  }

  void _changeRole(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E212D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2E3440)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Phân quyền cho ${user.displayName}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tài khoản: @${user.username}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...[UserRole.reader, UserRole.staff, UserRole.admin].map((role) {
                  final isCurrent = user.role == role;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Icon(role.icon, color: role.color),
                    title: Text(
                      role.label,
                      style: TextStyle(
                        color: isCurrent ? role.color : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      _getRoleDescription(role),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: isCurrent ? Icon(Icons.check_circle_rounded, color: role.color) : null,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await _auth.updateUserRole(user.id, role);
                      _refresh();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Đã cập nhật quyền của @${user.username} thành ${role.label}!'),
                          backgroundColor: const Color(0xFF00B894),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.reader:
        return 'Xem, tìm kiếm, lưu yêu thích & theo dõi tiến độ đọc';
      case UserRole.staff:
        return 'Toàn quyền Reader + Thêm truyện mới & Sửa thông tin truyện';
      case UserRole.admin:
        return 'Toàn quyền Staff + Xóa truyện & Quản lý phân quyền user';
      case UserRole.guest:
        return '';
    }
  }

  void _confirmDelete(AppUser user) {
    if (user.id == _auth.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa tài khoản Admin đang đăng nhập!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: const Text('Xác nhận xóa tài khoản', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản "${user.username}" (${user.displayName})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _auth.deleteUser(user.id);
              _refresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? const Color(0xFF00B894) : const Color(0xFFD63031),
                  ),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Người Dùng & Phân Quyền'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _users.isEmpty
              ? const Center(child: Text('Không có tài khoản nào trong hệ thống.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _users.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isCurrent = user.id == _auth.currentUser.id;

                    return Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF6C5CE7).withValues(alpha: 0.6)
                              : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE)),
                          width: isCurrent ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: user.role.color.withValues(alpha: 0.18),
                          foregroundColor: user.role.color,
                          child: Icon(user.role.icon),
                        ),
                        title: Row(
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Bạn',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.role.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: user.role.color.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                user.role.label,
                                style: TextStyle(
                                  color: user.role.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF6C5CE7)),
                              tooltip: 'Đổi quyền',
                              onPressed: () => _changeRole(user),
                            ),
                            if (!isCurrent)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                tooltip: 'Xóa tài khoản',
                                onPressed: () => _confirmDelete(user),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
