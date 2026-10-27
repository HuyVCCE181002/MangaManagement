import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'detail_screen.dart';
import 'push_notification_screen.dart';
import 'wallet_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    // Tự động tắt bất kỳ popup/SnackBar nào còn đang nổi khi mở màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });

    _notificationService.addListener(_onNotificationsChanged);
    _notificationService.loadNotifications();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _handleNotificationTap(NotificationItem item) async {
    // Đánh dấu đã đọc
    if (!item.isRead) {
      await _notificationService.markAsRead(item.id);
    }

    if (!mounted) return;

    // Điều hướng theo dữ liệu thông báo
    final mangaId = item.data?['mangaId'] as String?;
    if (mangaId != null && mangaId.isNotEmpty) {
      try {
        final manga = await DatabaseHelper.instance.getMangaById(mangaId);
        if (manga != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MangaDetailScreen(mangaId: manga.id),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    if (mounted &&
        (item.category == NotificationCategory.depositSuccess ||
            item.category == NotificationCategory.depositFailed ||
            item.category == NotificationCategory.chapterPurchased)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _notificationService.notifications;
    final unreadCount = _notificationService.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thông Báo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Nút tạo & gửi thông báo hệ thống dành cho Admin / Staff (UC-50)
          if (AuthService.instance.currentUser.role.canPushNotification)
            IconButton(
              tooltip: 'Gửi thông báo hệ thống (Admin/Staff)',
              icon: const Icon(Icons.campaign_rounded, color: Color(0xFF6C5CE7)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PushNotificationScreen(),
                  ),
                );
              },
            ),
          // Đánh dấu tất cả đã đọc
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: items.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _notificationService.markAllAsRead();
                    if (mounted) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Đã đánh dấu tất cả thông báo là đã đọc.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
          ),
          // Xóa tất cả thông báo
          IconButton(
            tooltip: 'Xóa tất cả thông báo',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: items.isEmpty
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xác nhận xóa tất cả'),
                        content: const Text(
                            'Bạn có chắc chắn muốn xóa toàn bộ lịch sử thông báo không?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Hủy'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Xóa tất cả'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _notificationService.clearAll();
                    }
                  },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 54,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có thông báo nào',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bạn sẽ nhận được thông báo khi có chương mới hoặc tương tác.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildNotificationCard(context, item, isDark, theme);
              },
            ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItem item,
    bool isDark,
    ThemeData theme,
  ) {
    final bgColor = item.isRead
        ? (isDark ? const Color(0xFF1E222D) : Colors.white)
        : (isDark ? const Color(0xFF262C3D) : const Color(0xFFF3F0FF));

    final borderColor = item.isRead
        ? (isDark ? const Color(0xFF2D3243) : const Color(0xFFE8EAF0))
        : const Color(0xFF6C5CE7).withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: item.isRead ? 1 : 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon thông báo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),

              // Nội dung thông báo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Tag nhãn thể loại
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Thời gian
                        Text(
                          item.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
