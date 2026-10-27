import 'dart:convert';
import 'package:flutter/material.dart';

class NotificationCategory {
  static const String newChapter = 'new_chapter';
  static const String depositSuccess = 'deposit_success';
  static const String depositFailed = 'deposit_failed';
  static const String chapterPurchased = 'chapter_purchased';
  static const String staffChapterAction = 'staff_chapter_action';
  static const String system = 'system';
}

class NotificationItem {
  final String id;
  final String? userId; // null nếu là broadcast cho nhiều người
  final String category;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    this.userId,
    required this.category,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? category,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'title': title,
      'message': message,
      'data': data != null ? jsonEncode(data) : null,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedData;
    if (map['data'] != null) {
      if (map['data'] is String) {
        try {
          parsedData = jsonDecode(map['data'] as String) as Map<String, dynamic>?;
        } catch (_) {}
      } else if (map['data'] is Map) {
        parsedData = Map<String, dynamic>.from(map['data'] as Map);
      }
    }

    return NotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      category: map['category'] as String? ?? NotificationCategory.system,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      data: parsedData,
      isRead: (map['is_read'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    if (json['data'] != null) {
      if (json['data'] is String) {
        try {
          parsedData = jsonDecode(json['data'] as String) as Map<String, dynamic>?;
        } catch (_) {}
      } else if (json['data'] is Map) {
        parsedData = Map<String, dynamic>.from(json['data'] as Map);
      }
    }

    return NotificationItem(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      category: json['category'] as String? ?? NotificationCategory.system,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      data: parsedData,
      isRead: json['isRead'] == true || (json['is_read'] as num?)?.toInt() == 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  IconData get icon {
    switch (category) {
      case NotificationCategory.newChapter:
        return Icons.auto_stories_rounded;
      case NotificationCategory.depositSuccess:
        return Icons.account_balance_wallet_rounded;
      case NotificationCategory.depositFailed:
        return Icons.error_outline_rounded;
      case NotificationCategory.chapterPurchased:
        return Icons.lock_open_rounded;
      case NotificationCategory.staffChapterAction:
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    switch (category) {
      case NotificationCategory.newChapter:
        return const Color(0xFF6C5CE7); // Tím hiện đại
      case NotificationCategory.depositSuccess:
        return const Color(0xFF00B894); // Xanh lá thành công
      case NotificationCategory.depositFailed:
        return const Color(0xFFD63031); // Đỏ lỗi
      case NotificationCategory.chapterPurchased:
        return const Color(0xFFFD79A8); // Cam hồng
      case NotificationCategory.staffChapterAction:
        return const Color(0xFFE17055); // Cam nâu staff
      default:
        return const Color(0xFF636E72);
    }
  }

  String get categoryLabel {
    switch (category) {
      case NotificationCategory.newChapter:
        return 'Chương mới';
      case NotificationCategory.depositSuccess:
        return 'Nạp tiền thành công';
      case NotificationCategory.depositFailed:
        return 'Nạp tiền thất bại';
      case NotificationCategory.chapterPurchased:
        return 'Mua chương';
      case NotificationCategory.staffChapterAction:
        return 'Tác vụ Staff';
      default:
        return 'Hệ thống';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
