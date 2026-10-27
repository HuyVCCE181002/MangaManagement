import 'package:uuid/uuid.dart';
import '../models/notification_item.dart';
import 'notification_server_io.dart'
    if (dart.library.html) 'notification_server_web.dart';

/// Backend Notification Service (Dart BE)
/// Quản lý WebSocket Server và broadcast sự kiện thời gian thực xuống các client FE.
class NotificationServerService {
  static final NotificationServerService instance =
      NotificationServerService._internal();
  NotificationServerService._internal();

  final NotificationServerPlatform _platform = NotificationServerPlatform();

  bool get isRunning => _platform.isRunning;
  int get activeConnections => _platform.activeConnections;

  /// Khởi chạy WebSocket server (mặc định cổng 8085)
  Future<bool> startServer({int port = 8085}) async {
    return await _platform.startServer(port: port);
  }

  /// Dừng server
  Future<void> stopServer() async {
    await _platform.stopServer();
  }

  /// 1. Bắn thông báo Chapter mới ra mắt
  /// Độc giả nào có truyện trong danh sách Yêu thích/Theo dõi sẽ hiển thị chuông báo.
  void notifyNewChapter({
    required String mangaId,
    required String mangaTitle,
    required int chapterNumber,
    String? chapterTitle,
  }) {
    final notif = NotificationItem(
      id: const Uuid().v4(),
      userId: null, // Broadcast, client FE lọc theo manga yêu thích / bookmark
      category: NotificationCategory.newChapter,
      title: 'Chương mới: $mangaTitle',
      message:
          'Chương $chapterNumber ${chapterTitle != null && chapterTitle.isNotEmpty ? "- $chapterTitle" : ""} vừa được phát hành!',
      data: {
        'mangaId': mangaId,
        'mangaTitle': mangaTitle,
        'chapterNumber': chapterNumber,
        'chapterTitle': chapterTitle,
      },
      createdAt: DateTime.now(),
    );

    _platform.broadcast(notif);
  }

  /// 2. Bắn thông báo Nạp tiền thành công
  void notifyDepositSuccess({
    required String userId,
    required int coins,
    required int amountVnd,
    String? orderCode,
  }) {
    final notif = NotificationItem(
      id: const Uuid().v4(),
      userId: userId,
      category: NotificationCategory.depositSuccess,
      title: 'Nạp tiền thành công! 💰',
      message:
          'Bạn đã nạp thành công +$coins coins vào ví (Mã: ${orderCode ?? "Nạp trực tiếp"}).',
      data: {
        'coins': coins,
        'amountVnd': amountVnd,
        'orderCode': orderCode,
      },
      createdAt: DateTime.now(),
    );

    _platform.broadcast(notif, targetUserId: userId);
  }

  /// 4b. Bắn thông báo Nạp tiền thất bại
  void notifyDepositFailed({
    required String userId,
    required String reason,
    String? orderCode,
  }) {
    final notif = NotificationItem(
      id: const Uuid().v4(),
      userId: userId,
      category: NotificationCategory.depositFailed,
      title: 'Nạp tiền thất bại ❌',
      message:
          'Giao dịch nạp tiền ${orderCode != null ? "($orderCode)" : ""} không thành công: $reason',
      data: {
        'orderCode': orderCode,
        'reason': reason,
      },
      createdAt: DateTime.now(),
    );

    _platform.broadcast(notif, targetUserId: userId);
  }

  /// 5. Bắn thông báo Mua chương thành công
  void notifyChapterPurchased({
    required String userId,
    required String mangaTitle,
    required int chapterNumber,
    required int coinsSpent,
    String? chapterId,
    String? mangaId,
  }) {
    final notif = NotificationItem(
      id: const Uuid().v4(),
      userId: userId,
      category: NotificationCategory.chapterPurchased,
      title: 'Mở khóa chương thành công 📖',
      message: 'Đã mở khóa Chương $chapterNumber - $mangaTitle (-$coinsSpent coins).',
      data: {
        'mangaId': mangaId,
        'chapterId': chapterId,
        'chapterNumber': chapterNumber,
        'mangaTitle': mangaTitle,
        'coinsSpent': coinsSpent,
      },
      createdAt: DateTime.now(),
    );

    _platform.broadcast(notif, targetUserId: userId);
  }

  /// 6. Bắn thông báo dành cho Staff (Thêm / Sửa / Xóa chương thành công hoặc thất bại)
  void notifyStaffChapterAction({
    required String staffId,
    required String action, // 'add', 'update', 'delete'
    required bool isSuccess,
    required String mangaTitle,
    required int chapterNumber,
    String? errorDetails,
    String? mangaId,
  }) {
    String actionName;
    switch (action) {
      case 'add':
        actionName = 'Thêm chương';
        break;
      case 'update':
        actionName = 'Cập nhật chương';
        break;
      case 'delete':
        actionName = 'Xóa chương';
        break;
      default:
        actionName = 'Thao tác chương';
    }

    final title = isSuccess
        ? 'Staff: $actionName thành công ✅'
        : 'Staff: $actionName thất bại ⚠️';

    final message = isSuccess
        ? 'Đã $actionName $chapterNumber của truyện "$mangaTitle" thành công.'
        : '$actionName $chapterNumber thất bại: ${errorDetails ?? "Lỗi không xác định"}';

    final notif = NotificationItem(
      id: const Uuid().v4(),
      userId: staffId,
      category: NotificationCategory.staffChapterAction,
      title: title,
      message: message,
      data: {
        'action': action,
        'isSuccess': isSuccess,
        'mangaId': mangaId,
        'mangaTitle': mangaTitle,
        'chapterNumber': chapterNumber,
        'error': errorDetails,
      },
      createdAt: DateTime.now(),
    );

    // Phát cho staff đã thực hiện và toàn bộ staff online
    _platform.broadcast(notif, targetRole: 'staff');
  }

  /// Bắn thông báo tùy biến
  void broadcastCustom(NotificationItem item,
      {String? targetUserId, String? targetRole}) {
    _platform.broadcast(item,
        targetUserId: targetUserId, targetRole: targetRole);
  }
}
