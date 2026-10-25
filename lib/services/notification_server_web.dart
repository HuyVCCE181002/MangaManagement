import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';

// Stream controller for in-memory broadcasting on web
final StreamController<NotificationItem> webNotificationBus =
    StreamController<NotificationItem>.broadcast();

class NotificationServerPlatform {
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  int get activeConnections => 1;

  Future<bool> startServer({int port = 8085}) async {
    _isRunning = true;
    debugPrint('[NotificationServer] In-memory Web Notification bus active');
    return true;
  }

  void broadcast(NotificationItem notification,
      {String? targetUserId, String? targetRole}) {
    webNotificationBus.add(notification);
  }

  Future<void> stopServer() async {
    _isRunning = false;
  }
}
