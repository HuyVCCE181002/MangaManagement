import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';

final StreamController<NotificationItem> webNotificationBus =
    StreamController<NotificationItem>.broadcast();

class ClientSession {
  final WebSocket socket;
  String? userId;
  String? role;

  ClientSession({required this.socket, this.userId, this.role});
}

class NotificationServerPlatform {
  HttpServer? _server;
  final List<ClientSession> _sessions = [];
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int get activeConnections => _sessions.length;

  Future<bool> startServer({int port = 8085}) async {
    if (_isRunning) return true;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _isRunning = true;
      debugPrint('[NotificationServer] WebSocket Server listening on port $port');

      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/ws') {
          try {
            final socket = await WebSocketTransformer.upgrade(request);
            final session = ClientSession(socket: socket);
            _sessions.add(session);
            debugPrint('[NotificationServer] Client connected (Total: ${_sessions.length})');

            socket.listen(
              (data) {
                _handleClientMessage(session, data);
              },
              onDone: () {
                _sessions.remove(session);
                debugPrint('[NotificationServer] Client disconnected (Remaining: ${_sessions.length})');
              },
              onError: (err) {
                _sessions.remove(session);
                debugPrint('[NotificationServer] Client error: $err');
              },
            );
          } catch (e) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.close();
          }
        } else if (request.uri.path == '/health') {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ok', 'activeConnections': _sessions.length}))
            ..close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });
      return true;
    } catch (e) {
      debugPrint('[NotificationServer] Failed to start WebSocket server on port $port: $e');
      _isRunning = false;
      return false;
    }
  }

  void _handleClientMessage(ClientSession session, dynamic rawData) {
    try {
      final json = jsonDecode(rawData as String);
      if (json is Map) {
        final action = json['action'];
        if (action == 'register') {
          session.userId = json['userId'] as String?;
          session.role = json['role'] as String?;
          debugPrint('[NotificationServer] Client registered: userId=${session.userId}, role=${session.role}');
          session.socket.add(jsonEncode({
            'type': 'registered',
            'userId': session.userId,
            'role': session.role,
          }));
        } else if (action == 'ping') {
          session.socket.add(jsonEncode({'type': 'pong'}));
        }
      }
    } catch (_) {}
  }

  void broadcast(NotificationItem notification, {String? targetUserId, String? targetRole}) {
    final payload = jsonEncode({
      'type': 'notification',
      ...notification.toJson(),
    });

    for (final session in List<ClientSession>.from(_sessions)) {
      bool shouldSend = true;

      if (targetUserId != null && session.userId != null) {
        if (session.userId != targetUserId) {
          shouldSend = false;
        }
      }

      if (targetRole != null && targetRole.isNotEmpty && targetRole != 'all') {
        final clientRole = session.role ?? 'guest';
        if (targetRole == 'admin') {
          if (clientRole != 'admin') {
            shouldSend = false;
          }
        } else if (targetRole == 'staff') {
          // Staff notification: gửi tới staff và admin
          if (clientRole != 'staff' && clientRole != 'admin') {
            shouldSend = false;
          }
        } else if (targetRole == 'user') {
          // User notification: bao gồm reader và guest
          if (clientRole != 'reader' && clientRole != 'guest') {
            shouldSend = false;
          }
        } else {
          if (clientRole != targetRole && clientRole != 'admin') {
            shouldSend = false;
          }
        }
      }

      if (shouldSend) {
        try {
          session.socket.add(payload);
        } catch (e) {
          debugPrint('[NotificationServer] Error sending to client: $e');
        }
      }
    }
  }

  Future<void> stopServer() async {
    for (final session in List<ClientSession>.from(_sessions)) {
      try {
        await session.socket.close();
      } catch (_) {}
    }
    _sessions.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }
}
