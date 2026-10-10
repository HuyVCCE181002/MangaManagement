enum MangaSortBy {
  updatedDesc,
  ratingDesc,
  titleAsc,
  chaptersDesc,
}

/// Tiêu chí lọc và sắp xếp truyện tranh
class MangaFilter {
  final String? query;
  final List<String> genres;
  final String? status;
  final double? minRating;
  final MangaSortBy sortBy;

  const MangaFilter({
    this.query,
    this.genres = const [],
    this.status,
    this.minRating,
    this.sortBy = MangaSortBy.updatedDesc,
  });

  bool get hasActiveFilter =>
      (query != null && query!.trim().isNotEmpty) ||
      genres.isNotEmpty ||
      (status != null && status!.isNotEmpty) ||
      (minRating != null && minRating! > 0);

  MangaFilter copyWith({
    String? query,
    List<String>? genres,
    String? status,
    double? minRating,
    MangaSortBy? sortBy,
  }) {
    return MangaFilter(
      query: query ?? this.query,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      minRating: minRating ?? this.minRating,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  MangaFilter clearFilters() {
    return MangaFilter(query: query);
  }
}
