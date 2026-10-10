import '../../domain/entities/manga.dart';

/// Manga Data Model (DTO) để serialize/deserialize JSON từ REST API & Local Cache
class MangaModel {
  final String id;
  final String title;
  final String? originalTitle;
  final String author;
  final String? artist;
  final String description;
  final String coverUrl;
  final List<String> genres;
  final String status;
  final int totalChapters;
  final int currentChapter;
  final double rating;
  final int releaseYear;
  final DateTime updatedAt;

  const MangaModel({
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

  factory MangaModel.fromJson(Map<String, dynamic> json) {
    return MangaModel(
      id: json['id'] as String,
      title: json['title'] as String,
      originalTitle: json['originalTitle'] as String?,
      author: json['author'] as String,
      artist: json['artist'] as String?,
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'Ongoing',
      totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      releaseYear: (json['releaseYear'] as num?)?.toInt() ?? DateTime.now().year,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'originalTitle': originalTitle,
      'author': author,
      'artist': artist,
      'description': description,
      'coverUrl': coverUrl,
      'genres': genres,
      'status': status,
      'totalChapters': totalChapters,
      'currentChapter': currentChapter,
      'rating': rating,
      'releaseYear': releaseYear,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Manga toEntity() {
    return Manga(
      id: id,
      title: title,
      originalTitle: originalTitle,
      author: author,
      artist: artist,
      description: description,
      coverUrl: coverUrl,
      genres: genres,
      status: status,
      totalChapters: totalChapters,
      currentChapter: currentChapter,
      rating: rating,
      releaseYear: releaseYear,
      updatedAt: updatedAt,
    );
  }

  factory MangaModel.fromEntity(Manga entity) {
    return MangaModel(
      id: entity.id,
      title: entity.title,
      originalTitle: entity.originalTitle,
      author: entity.author,
      artist: entity.artist,
      description: entity.description,
      coverUrl: entity.coverUrl,
      genres: entity.genres,
      status: entity.status,
      totalChapters: entity.totalChapters,
      currentChapter: entity.currentChapter,
      rating: entity.rating,
      releaseYear: entity.releaseYear,
      updatedAt: entity.updatedAt,
    );
  }
}
