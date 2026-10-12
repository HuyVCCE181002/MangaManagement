class Manga {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String genre; // Thể loại chính (Action, Romance, Comedy, Fantasy...)
  final String status; // 'Ongoing' (Đang ra) hoặc 'Completed' (Hoàn thành)
  final int totalChapters;
  final int currentChapter; // Tiến độ đọc hiện tại
  final double rating; // Điểm 0.0 - 10.0
  final bool isFavorite;

  Manga({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.genre,
    required this.status,
    required this.totalChapters,
    this.currentChapter = 0,
    required this.rating,
    this.isFavorite = false,
  });

  double get progressPercentage {
    if (totalChapters <= 0) return 0.0;
    return (currentChapter / totalChapters).clamp(0.0, 1.0);
  }

  Manga copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? genre,
    String? status,
    int? totalChapters,
    int? currentChapter,
    double? rating,
    bool? isFavorite,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      genre: genre ?? this.genre,
      status: status ?? this.status,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'coverUrl': coverUrl,
      'genre': genre,
      'status': status,
      'totalChapters': totalChapters,
      'currentChapter': currentChapter,
      'rating': rating,
      'isFavorite': isFavorite,
    };
  }

  /// Chuyển đổi đối tượng sang Map dùng để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'cover_url': coverUrl,
      'genre': genre,
      'status': status,
      'total_chapters': totalChapters,
      'current_chapter': currentChapter,
      'rating': rating,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  /// Khởi tạo đối tượng từ dữ liệu Map của SQLite hoặc JSON
  factory Manga.fromMap(Map<String, dynamic> map) {
    return Manga(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      description: map['description'] as String? ?? '',
      coverUrl: (map['cover_url'] ?? map['coverUrl']) as String? ?? '',
      genre: map['genre'] as String? ?? 'Action',
      status: map['status'] as String? ?? 'Ongoing',
      totalChapters: (map['total_chapters'] ?? map['totalChapters'] as num?)?.toInt() ?? 0,
      currentChapter: (map['current_chapter'] ?? map['currentChapter'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 8.0,
      isFavorite: (map['is_favorite'] == 1 || map['is_favorite'] == true || map['isFavorite'] == 1 || map['isFavorite'] == true),
    );
  }
}
