import '../../domain/entities/review.dart';

class ReviewModel {
  final String id;
  final String mangaId;
  final double score;
  final String note;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.mangaId,
    required this.score,
    required this.note,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      mangaId: json['mangaId'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 5.0,
      note: json['note'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mangaId': mangaId,
      'score': score,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Review toEntity() {
    return Review(
      id: id,
      mangaId: mangaId,
      score: score,
      note: note,
      createdAt: createdAt,
    );
  }

  factory ReviewModel.fromEntity(Review entity) {
    return ReviewModel(
      id: entity.id,
      mangaId: entity.mangaId,
      score: entity.score,
      note: entity.note,
      createdAt: entity.createdAt,
    );
  }
}
