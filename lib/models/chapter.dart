import 'dart:convert';

/// Model đại diện cho một chương (Chapter) truyện tranh
class Chapter {
  final String id;
  final String mangaId;
  final int chapterNumber;
  final String title;
  final List<String> contents; // Danh sách URL hình ảnh theo đúng thứ tự đọc
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLocked;
  final bool isDeleted; // Cờ xóa mềm (Soft Delete)
  final double price; // Giá chương (0.0 = miễn phí)

  Chapter({
    required this.id,
    required this.mangaId,
    required this.chapterNumber,
    required this.title,
    required this.contents,
    required this.createdAt,
    required this.updatedAt,
    this.isLocked = false,
    this.isDeleted = false,
    this.price = 0.0,
  });

  /// Tạo bản sao bất biến với các trường được cập nhật
  Chapter copyWith({
    String? id,
    String? mangaId,
    int? chapterNumber,
    String? title,
    List<String>? contents,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLocked,
    bool? isDeleted,
    double? price,
  }) {
    return Chapter(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      title: title ?? this.title,
      contents: contents ?? this.contents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocked: isLocked ?? this.isLocked,
      isDeleted: isDeleted ?? this.isDeleted,
      price: price ?? this.price,
    );
  }

  /// Chuyển đổi sang Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'chapter_number': chapterNumber,
      'title': title,
      'contents': jsonEncode(contents), // Lưu danh sách URL dưới dạng chuỗi JSON
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_locked': isLocked ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'price': price,
    };
  }

  /// Khởi tạo đối tượng từ dữ liệu Map của SQLite hoặc JSON
  factory Chapter.fromMap(Map<String, dynamic> map) {
    List<String> parsedContents = [];
    final rawContents = map['contents'];
    if (rawContents != null) {
      if (rawContents is List) {
        parsedContents = rawContents.map((e) => e.toString()).toList();
      } else if (rawContents is String && rawContents.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawContents);
          if (decoded is List) {
            parsedContents = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          parsedContents = [];
        }
      }
    }

    DateTime parseDate(dynamic dateVal) {
      if (dateVal is String && dateVal.isNotEmpty) {
        try {
          return DateTime.parse(dateVal);
        } catch (_) {}
      }
      return DateTime.now();
    }

    return Chapter(
      id: map['id'] as String? ?? '',
      mangaId: (map['manga_id'] ?? map['mangaId']) as String? ?? '',
      chapterNumber: ((map['chapter_number'] ?? map['chapterNumber']) as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? '',
      contents: parsedContents,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
      isLocked: map['is_locked'] == 1 || map['is_locked'] == true || map['isLocked'] == 1 || map['isLocked'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == 1 || map['isDeleted'] == true,
      price: ((map['price'] as num?)?.toDouble()) ?? 0.0,
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter.fromMap(json);

  Map<String, dynamic> toJson() => toMap();
}
