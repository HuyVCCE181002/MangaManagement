class Bookmark {
  final String userId;
  final String mangaId;
  final String chapterId;
  final DateTime createdAt;

  Bookmark({
    required this.userId,
    required this.mangaId,
    required this.chapterId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'manga_id': mangaId,
      'chapter_id': chapterId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      userId: map['user_id'] as String,
      mangaId: map['manga_id'] as String,
      chapterId: map['chapter_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class BookmarkDetail {
  final Bookmark bookmark;
  final String mangaTitle;
  final String coverUrl;
  final String chapterTitle;
  final int chapterNumber;

  BookmarkDetail({
    required this.bookmark,
    required this.mangaTitle,
    required this.coverUrl,
    required this.chapterTitle,
    required this.chapterNumber,
  });
}
