import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/notification_item.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_helper.dart';
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
      _notifications = await DatabaseHelper.instance.getNotifications(
        userId: userId,
        limit: 100,
      );
      _unreadCount = await DatabaseHelper.instance.getUnreadNotificationCount(
        userId: userId,
      );
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

  /// Xử lý một notification mới nhận được
  Future<void> _handleIncomingNotification(NotificationItem item) async {
    final currentUser = AuthService.instance.currentUser;

    // 1. Kiểm tra đối tượng nhận:
    // Nếu là thông báo Chapter mới: Kiểm tra truyện có nằm trong mục Yêu thích / Bookmark của user không
    if (item.category == NotificationCategory.newChapter) {
      final mangaId = item.data?['mangaId'] as String?;
      if (mangaId != null) {
        bool isInterested = false;

        // Nếu là staff/admin, luôn nhận để kiểm soát nội dung
        if (currentUser.role == UserRole.staff || currentUser.role == UserRole.admin) {
          isInterested = true;
        } else if (!currentUser.isGuest) {
          // Kiểm tra xem truyện này có được đánh dấu yêu thích hoặc bookmark không
          try {
            final manga = await DatabaseHelper.instance.getMangaById(mangaId);
            if (manga != null && manga.isFavorite) {
              isInterested = true;
            } else {
              final bookmarks = await DatabaseHelper.instance.getUserBookmarks(currentUser.id);
              if (bookmarks.any((b) => b.bookmark.mangaId == mangaId)) {
                isInterested = true;
              }
            }
          } catch (_) {
            isInterested = true; // Fallback hiển thị nếu không tra cứu được
          }
        } else {
          // Guest: nhận thông báo chương mới để thu hút đọc truyện
          isInterested = true;
        }

        if (!isInterested) {
          return; // Bỏ qua nếu truyện không thuộc danh sách yêu thích/theo dõi
        }
      }
    }

    // Nếu là thông báo Staff: chỉ hiển thị cho tài khoản có quyền staff hoặc admin
    if (item.category == NotificationCategory.staffChapterAction) {
      if (currentUser.role != UserRole.staff && currentUser.role != UserRole.admin) {
        return;
      }
    }

    // Nếu thông báo nhắm đến 1 user cụ thể: chỉ hiển thị nếu đúng currentUser.id
    if (item.userId != null && item.userId!.isNotEmpty) {
      if (currentUser.isGuest || item.userId != currentUser.id) {
        return;
      }
    }

    // 2. Lưu vào SQLite
    try {
      await DatabaseHelper.instance.insertNotification(item);
    } catch (e) {
      debugPrint('[NotificationService] Error caching notification: $e');
    }

    // 3. Tự động thêm vào danh sách và làm mới chuông báo
    _notifications.removeWhere((n) => n.id == item.id);
    _notifications.insert(0, item);
    _unreadCount++;

    // Bắn ra stream thông báo mới để giao diện hiển thị Popup/SnackBar
    _newNotificationStreamController.add(item);

    // Kích hoạt notifyListeners để UI cập nhật tự động
    notifyListeners();
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();

      await DatabaseHelper.instance.markNotificationAsRead(id);
    }
  }

  /// Đánh dấu tất cả là đã đọc
  Future<void> markAllAsRead() async {
    final user = AuthService.instance.currentUser;
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    await DatabaseHelper.instance.markAllNotificationsAsRead(
      userId: user.isGuest ? null : user.id,
    );
  }

  /// Xóa một thông báo
  Future<void> deleteNotification(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final wasUnread = !_notifications[index].isRead;
      _notifications.removeAt(index);
      if (wasUnread && _unreadCount > 0) _unreadCount--;
      notifyListeners();

      await DatabaseHelper.instance.deleteNotification(id);
    }
  }

  /// Xóa tất cả thông báo
  Future<void> clearAll() async {
    final user = AuthService.instance.currentUser;
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();

    await DatabaseHelper.instance.clearAllNotifications(
      userId: user.isGuest ? null : user.id,
    );
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
