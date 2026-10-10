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
    return Manga(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String,
      genre: json['genre'] as String? ?? 'Action',
      status: json['status'] as String? ?? 'Ongoing',
      totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 8.0,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
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
}
