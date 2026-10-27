import 'package:flutter_test/flutter_test.dart';
import 'package:manga_management_app/models/notification_item.dart';
import 'package:manga_management_app/services/auth_service.dart';
import 'package:manga_management_app/services/database_helper.dart';
import 'package:manga_management_app/services/notification_service.dart';
import 'package:manga_management_app/services/notification_server_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setDbNameForTesting('manga_vault_notif_test.db');
  });

  group('NotificationService & NotificationServerService - WebSocket Integration Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.resetToDefault();
      await DatabaseHelper.instance.clearAllNotifications();
      await AuthService.instance.init();
    });

    tearDown(() async {
      NotificationService.instance.disconnect();
      await NotificationServerService.instance.stopServer();
      await Future.delayed(const Duration(milliseconds: 200));
    });

    test('Server starts and broadcasts notifications across WebSocket', () async {
      final server = NotificationServerService.instance;
      final started = await server.startServer(port: 8091);
      expect(started, isTrue);

      // Đăng nhập tài khoản reader
      final loginResult = await AuthService.instance.login('reader', 'reader123');
      expect(loginResult.success, isTrue);

      final client = NotificationService.instance;
      client.connect(wsUrl: 'ws://127.0.0.1:8091/ws');

      // Chờ WebSocket handshake hoàn tất
      await Future.delayed(const Duration(milliseconds: 600));
      expect(client.isConnected, isTrue);

      // 1. Test broadcast Chapter mới (One Piece có id là '1', mặc định isFavorite = true)
      server.notifyNewChapter(
        mangaId: '1',
        mangaTitle: 'One Piece',
        chapterNumber: 1115,
        chapterTitle: 'Tương Lai Mới',
      );

      // 2. Test nạp tiền thành công
      server.notifyDepositSuccess(
        userId: 'reader_1',
        coins: 100,
        amountVnd: 10000,
        orderCode: 'TEST-ORD-01',
      );

      // 3. Test mua chương thành công
      server.notifyChapterPurchased(
        userId: 'reader_1',
        mangaTitle: 'One Piece',
        chapterNumber: 1,
        coinsSpent: 10,
        mangaId: '1',
      );

      // Chờ các gói tin WebSocket truyền nhận và lưu vào SQLite
      await Future.delayed(const Duration(milliseconds: 600));

      // Kiểm tra notifications đã được nhận
      final notifs = await DatabaseHelper.instance.getNotifications(userId: 'reader_1');
      expect(notifs.length, greaterThanOrEqualTo(3));

      final categories = notifs.map((n) => n.category).toSet();
      expect(categories.contains(NotificationCategory.newChapter), isTrue);
      expect(categories.contains(NotificationCategory.depositSuccess), isTrue);
      expect(categories.contains(NotificationCategory.chapterPurchased), isTrue);

      // Kiểm tra số lượng unread
      final unread = await DatabaseHelper.instance.getUnreadNotificationCount(userId: 'reader_1');
      expect(unread, greaterThanOrEqualTo(3));

      // Đánh dấu tất cả đã đọc
      await client.markAllAsRead();
      final unreadAfter = await DatabaseHelper.instance.getUnreadNotificationCount(userId: 'reader_1');
      expect(unreadAfter, 0);
    });

    test('Staff chapter action notifications are routed to staff role', () async {
      final server = NotificationServerService.instance;
      await server.startServer(port: 8092);

      // Đăng nhập Staff
      final staffLogin = await AuthService.instance.login('staff', 'staff123');
      expect(staffLogin.success, isTrue);

      final client = NotificationService.instance;
      client.connect(wsUrl: 'ws://127.0.0.1:8092/ws');
      await Future.delayed(const Duration(milliseconds: 600));
      expect(client.isConnected, isTrue);

      // Bắn thông báo Staff thêm chương thành công
      server.notifyStaffChapterAction(
        staffId: 'staff_1',
        action: 'add',
        isSuccess: true,
        mangaTitle: 'Solo Leveling',
        chapterNumber: 200,
      );

      // Bắn thông báo Staff xóa chương thất bại
      server.notifyStaffChapterAction(
        staffId: 'staff_1',
        action: 'delete',
        isSuccess: false,
        mangaTitle: 'Solo Leveling',
        chapterNumber: 999,
        errorDetails: 'Lỗi ràng buộc khóa ngoại',
      );

      await Future.delayed(const Duration(milliseconds: 600));

      final staffNotifs = await DatabaseHelper.instance.getNotifications(
        category: NotificationCategory.staffChapterAction,
      );
      expect(staffNotifs.length, greaterThanOrEqualTo(2));
    });
  });
}
