/// Thực thể đánh giá và ghi chú cá nhân của người dùng cho từng bộ truyện
class Review {
  final String id;
  final String mangaId;
  final double score; // 1.0 - 5.0 sao
  final String note; // Cảm nhận, ghi chú riêng (ví dụ: "Đoạn arc 3 rất hay")
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.mangaId,
    required this.score,
    required this.note,
    required this.createdAt,
  });

  Review copyWith({
    String? id,
    String? mangaId,
    double? score,
    String? note,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      score: score ?? this.score,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
