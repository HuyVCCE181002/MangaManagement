/// Thực thể Manga thuần túy thuộc tầng Domain (không phụ thuộc vào UI hay external library)
class Manga {
  final String id;
  final String title;
  final String? originalTitle; // Tên gốc tiếng Nhật / Hàn
  final String author;
  final String? artist;
  final String description;
  final String coverUrl;
  final List<String> genres;
  final String status; // 'Ongoing', 'Completed', 'Hiatus'
  final int totalChapters;
  final int currentChapter; // Tiến độ đọc hiện tại của người dùng
  final double rating; // Thang điểm 0.0 - 10.0
  final int releaseYear;
  final DateTime updatedAt;

  const Manga({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.author,
    this.artist,
    required this.description,
    required this.coverUrl,
    required this.genres,
    required this.status,
    required this.totalChapters,
    this.currentChapter = 0,
    required this.rating,
    required this.releaseYear,
    required this.updatedAt,
  });

  bool get isCompleted => status.toLowerCase() == 'completed';

  double get readingProgressPercentage {
    if (totalChapters <= 0) return 0.0;
    final progress = currentChapter / totalChapters;
    return progress.clamp(0.0, 1.0);
  }

  Manga copyWith({
    String? id,
    String? title,
    String? originalTitle,
    String? author,
    String? artist,
    String? description,
    String? coverUrl,
    List<String>? genres,
    String? status,
    int? totalChapters,
    int? currentChapter,
    double? rating,
    int? releaseYear,
    DateTime? updatedAt,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      rating: rating ?? this.rating,
      releaseYear: releaseYear ?? this.releaseYear,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Manga && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
