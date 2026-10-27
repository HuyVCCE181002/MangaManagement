import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/notification_item.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'notification_server_service.dart';
import 'notification_server_web.dart' if (dart.library.io) 'notification_server_io.dart';

/// Frontend Notification Service (Flutter FE)
/// Lắng nghe WebSocket stream từ Dart Backend Server, tự động cập nhật SQLite,
/// tính toán số badge chưa đọc và notifyListeners để chuông báo/giao diện tự làm mới tức thì.
class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  static const String defaultWsUrl = String.fromEnvironment(
    'NOTIFICATION_WS_URL',
    defaultValue: 'ws://127.0.0.1:8085/ws',
  );

  WebSocketChannel? _channel;
  StreamSubscription? _webBusSubscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];

  // Stream để UI (ví dụ SnackBar) có thể lắng nghe sự kiện thông báo mới nổi lên
  final StreamController<NotificationItem> _newNotificationStreamController =
      StreamController<NotificationItem>.broadcast();
  Stream<NotificationItem> get onNewNotification =>
      _newNotificationStreamController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int get unreadCount => _unreadCount;
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  /// Khởi tạo và kết nối WebSocket
  Future<void> init() async {
    await loadNotifications();
    connect();

    // Hỗ trợ môi trường Web nếu WebSocket local không kết nối được
    if (kIsWeb) {
      _listenToWebBus();
    }
  }

  void _onAuthChanged() {
    loadNotifications();
    if (_isConnected && _channel != null) {
      _sendRegister();
    }
  }

  void _listenToWebBus() {
    _webBusSubscription?.cancel();
    try {
      _webBusSubscription = webNotificationBus.stream.listen((item) {
        _handleIncomingNotification(item);
      });
    } catch (_) {}
  }

  /// Tải thông báo từ SQLite database
  Future<void> loadNotifications() async {
    final user = AuthService.instance.currentUser;
    final userId = user.isGuest ? null : user.id;

    try {
      final rawNotifications = await DatabaseHelper.instance.getNotifications(
        userId: userId,
        limit: 100,
      );

      final List<NotificationItem> filtered = [];
      for (final raw in rawNotifications) {
        if (await _isNotificationForUser(raw, user)) {
          final isReadForUser = _isItemReadForUser(raw, user);
          filtered.add(raw.copyWith(isRead: isReadForUser));
        }
      }

      _notifications = filtered;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] Error loading notifications: $e');
    }
  }

  /// Kết nối tới WebSocket server
  void connect({String? wsUrl}) {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();

    final url = wsUrl ?? defaultWsUrl;
    try {
      debugPrint('[NotificationService] Connecting to WebSocket: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.ready.then((_) {
        _isConnected = true;
        _isConnecting = false;
        _startPingTimer();
        _sendRegister();
        notifyListeners();
        debugPrint('[NotificationService] WebSocket connected successfully!');
      }).catchError((error) {
        debugPrint('[NotificationService] WebSocket ready error: $error');
        _handleDisconnect();
      });

      _channel!.stream.listen(
        (data) {
          _handleRawMessage(data);
        },
        onDone: () {
          debugPrint('[NotificationService] WebSocket connection closed.');
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('[NotificationService] WebSocket error: $error');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to create WebSocket channel: $e');
      _handleDisconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }

  void _sendRegister() {
    final user = AuthService.instance.currentUser;
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'action': 'register',
          'userId': user.isGuest ? null : user.id,
          'role': user.role.name,
        }));
      } catch (_) {}
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'action': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();
    _channel = null;
    notifyListeners();

    // Tự động kết nối lại sau 4 giây
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      connect();
    });
  }

  void _handleRawMessage(dynamic rawData) {
    try {
      final json = jsonDecode(rawData as String);
      if (json is Map) {
        final type = json['type'];
        if (type == 'notification') {
          final item = NotificationItem.fromJson(Map<String, dynamic>.from(json));
          _handleIncomingNotification(item);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error parsing raw message: $e');
    }
  }

  /// Kiểm tra xem thông báo có thuộc đối tượng nhận của user hiện tại không
  Future<bool> _isNotificationForUser(NotificationItem item, AppUser user) async {
    // 1. Kiểm tra nếu user đã ẩn/xóa thông báo này (dismissedBy)
    final dismissedBy = (item.data?['dismissedBy'] as List?)?.cast<String>() ?? [];
    if (!user.isGuest && dismissedBy.contains(user.id)) {
      return false;
    }

    // 2. Nếu là thông báo gửi đích danh cho 1 user cụ thể (item.userId != null)
    if (item.userId != null && item.userId!.isNotEmpty) {
      if (user.isGuest || item.userId != user.id) {
        return false;
      }
      return true;
    }

    // 3. Nếu là thông báo Staff thao tác chương (staffChapterAction)
    if (item.category == NotificationCategory.staffChapterAction) {
      if (user.role != UserRole.staff && user.role != UserRole.admin) {
        return false;
      }
      return true;
    }

    // 4. Nếu là thông báo Chapter mới (newChapter) hoặc Cập nhật truyện/chương (mangaUpdated)
    if (item.category == NotificationCategory.newChapter ||
        item.category == NotificationCategory.mangaUpdated) {
      // Bỏ Guest: Khách vãng lai không nhận thông báo
      if (user.isGuest) {
        return false;
      }

      // Staff và Admin luôn nhận để theo dõi/kiểm duyệt nội dung
      if (user.role == UserRole.staff || user.role == UserRole.admin) {
        return true;
      }

      // Độc giả (Reader): CHỈ nhận nếu truyện ĐÃ ĐƯỢC YÊU THÍCH (isFavorite == true), bỏ qua bookmark
      final mangaId = item.data?['mangaId'] as String?;
      if (mangaId != null) {
        try {
          final manga = await DatabaseHelper.instance.getMangaById(mangaId);
          if (manga != null && manga.isFavorite) {
            return true;
          }
        } catch (_) {}
      }
      return false; // Chưa yêu thích thì không nhận thông báo
    }

    // 5. Nếu là thông báo Hệ thống (System Push) có chỉ định nhóm đối tượng
    final targetAudience = item.data?['targetAudience'] as String?;
    if (targetAudience != null && targetAudience.isNotEmpty && targetAudience != 'all') {
      if (targetAudience == 'admin') {
        return user.role == UserRole.admin;
      } else if (targetAudience == 'staff') {
        return user.role == UserRole.staff || user.role == UserRole.admin;
      } else if (targetAudience == 'user') {
        // 'user' nhắm đến người đọc (reader) và khách (guest).
        // Cho phép Staff và Admin xem được trong danh sách để quản lý lịch sử thông báo đã phát.
        return user.role == UserRole.reader ||
            user.isGuest ||
            user.role == UserRole.staff ||
            user.role == UserRole.admin;
      }
    }

    return true;
  }

  /// Kiểm tra trạng thái đã đọc của thông báo đối với user hiện tại
  bool _isItemReadForUser(NotificationItem item, AppUser user) {
    if (item.userId != null && item.userId!.isNotEmpty) {
      return item.isRead;
    }
    if (user.isGuest) {
      return item.isRead;
    }
    final readBy = (item.data?['readBy'] as List?)?.cast<String>() ?? [];
    return readBy.contains(user.id);
  }

  /// Xử lý một notification mới nhận được
  Future<void> _handleIncomingNotification(
    NotificationItem item, {
    bool isSender = false,
  }) async {
    final currentUser = AuthService.instance.currentUser;

    // 1. Luôn lưu vào SQLite để đảm bảo dữ liệu không bị thất lạc
    try {
      await DatabaseHelper.instance.insertNotification(item);
    } catch (e) {
      debugPrint('[NotificationService] Error caching notification: $e');
    }

    // 2. Kiểm tra đối tượng nhận
    final isForUser = await _isNotificationForUser(item, currentUser);
    if (!isForUser) {
      return;
    }

    // 3. Tự động thêm vào danh sách và làm mới chuông báo
    final isReadForUser = _isItemReadForUser(item, currentUser);
    final displayItem = item.copyWith(isRead: isReadForUser);

    _notifications.removeWhere((n) => n.id == item.id);
    _notifications.insert(0, displayItem);
    _unreadCount = _notifications.where((n) => !n.isRead).length;

    // Nếu không phải chính người gửi thì hiển thị Popup/SnackBar thông báo nổi
    if (!isSender) {
      _newNotificationStreamController.add(displayItem);
    }

    // Kích hoạt notifyListeners để UI cập nhật tự động
    notifyListeners();
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String id) async {
    final user = AuthService.instance.currentUser;
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final item = _notifications[index];
      final updatedData = Map<String, dynamic>.from(item.data ?? {});
      if (!user.isGuest) {
        final readBy = List<String>.from((updatedData['readBy'] as List?)?.cast<String>() ?? []);
        if (!readBy.contains(user.id)) {
          readBy.add(user.id);
          updatedData['readBy'] = readBy;
        }
      }

      final updatedItem = item.copyWith(
        isRead: true,
        data: updatedData,
      );

      _notifications[index] = updatedItem;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();

      if (item.userId != null || user.isGuest) {
        await DatabaseHelper.instance.markNotificationAsRead(id);
      } else {
        await DatabaseHelper.instance.insertNotification(updatedItem);
      }
    }
  }

  /// Đánh dấu tất cả là đã đọc
  Future<void> markAllAsRead() async {
    final user = AuthService.instance.currentUser;

    for (int i = 0; i < _notifications.length; i++) {
      final item = _notifications[i];
      if (!item.isRead) {
        final updatedData = Map<String, dynamic>.from(item.data ?? {});
        if (!user.isGuest) {
          final readBy = List<String>.from((updatedData['readBy'] as List?)?.cast<String>() ?? []);
          if (!readBy.contains(user.id)) {
            readBy.add(user.id);
            updatedData['readBy'] = readBy;
          }
        }
        final updatedItem = item.copyWith(isRead: true, data: updatedData);
        _notifications[i] = updatedItem;
        if (item.userId != null || user.isGuest) {
          await DatabaseHelper.instance.markNotificationAsRead(item.id);
        } else {
          await DatabaseHelper.instance.insertNotification(updatedItem);
        }
      }
    }

    _unreadCount = 0;
    notifyListeners();

    if (user.isGuest) {
      await DatabaseHelper.instance.markAllNotificationsAsRead();
    }
  }

  /// Xóa một thông báo
  Future<void> deleteNotification(String id) async {
    final user = AuthService.instance.currentUser;
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final item = _notifications[index];
      _notifications.removeAt(index);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();

      if (item.userId != null || user.isGuest) {
        await DatabaseHelper.instance.deleteNotification(id);
      } else {
        final updatedData = Map<String, dynamic>.from(item.data ?? {});
        final dismissedBy = List<String>.from((updatedData['dismissedBy'] as List?)?.cast<String>() ?? []);
        if (!dismissedBy.contains(user.id)) {
          dismissedBy.add(user.id);
          updatedData['dismissedBy'] = dismissedBy;
        }
        await DatabaseHelper.instance.insertNotification(item.copyWith(data: updatedData));
      }
    }
  }

  /// Xóa tất cả thông báo
  Future<void> clearAll() async {
    final user = AuthService.instance.currentUser;
    final itemsToClear = List<NotificationItem>.from(_notifications);
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();

    for (final item in itemsToClear) {
      if (item.userId != null || user.isGuest) {
        await DatabaseHelper.instance.deleteNotification(item.id);
      } else {
        final updatedData = Map<String, dynamic>.from(item.data ?? {});
        final dismissedBy = List<String>.from((updatedData['dismissedBy'] as List?)?.cast<String>() ?? []);
        if (!dismissedBy.contains(user.id)) {
          dismissedBy.add(user.id);
          updatedData['dismissedBy'] = dismissedBy;
        }
        await DatabaseHelper.instance.insertNotification(item.copyWith(data: updatedData));
      }
    }
  }

  /// Gửi push notification hệ thống (Admin & Staff)
  Future<void> pushSystemNotification({
    required String title,
    required String message,
    required String targetAudience, // 'all', 'user', 'staff', 'admin'
  }) async {
    final sender = AuthService.instance.currentUser;
    var item = NotificationServerService.instance.notifySystemPush(
      title: title,
      message: message,
      targetAudience: targetAudience,
      senderRole: sender.role.name,
      senderName: sender.displayName.isNotEmpty ? sender.displayName : sender.username,
    );

    // Đánh dấu người gửi đã đọc thông báo này
    if (!sender.isGuest) {
      final updatedData = Map<String, dynamic>.from(item.data ?? {});
      final readBy = List<String>.from((updatedData['readBy'] as List?)?.cast<String>() ?? []);
      if (!readBy.contains(sender.id)) {
        readBy.add(sender.id);
        updatedData['readBy'] = readBy;
      }
      item = item.copyWith(data: updatedData, isRead: true);
    }

    // 1. Luôn lưu thông báo vào SQLite ngay lập tức
    try {
      await DatabaseHelper.instance.insertNotification(item);
    } catch (e) {
      debugPrint('[NotificationService] Error caching pushed notification: $e');
    }

    // 2. Kích hoạt xử lý hiển thị cho chính client hiện tại
    await _handleIncomingNotification(item, isSender: true);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    _webBusSubscription?.cancel();
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _newNotificationStreamController.close();
    super.dispose();
  }
}
