import 'package:flutter/foundation.dart';
import 'package:manga_management_app/features/manga/domain/entities/manga_filter.dart';

class SearchFilterProvider extends ChangeNotifier {
  String _query = '';
  List<String> _selectedGenres = [];
  String? _selectedStatus;
  double _minRating = 0.0;
  MangaSortBy _sortBy = MangaSortBy.ratingDesc;

  String get query => _query;
  List<String> get selectedGenres => _selectedGenres;
  String? get selectedStatus => _selectedStatus;
  double get minRating => _minRating;
  MangaSortBy get sortBy => _sortBy;

  bool get hasActiveFilter =>
      _selectedGenres.isNotEmpty ||
      (_selectedStatus != null && _selectedStatus!.isNotEmpty) ||
      _minRating > 0 ||
      _sortBy != MangaSortBy.ratingDesc;

  MangaFilter toFilter() {
    return MangaFilter(
      query: _query.trim().isEmpty ? null : _query.trim(),
      genres: _selectedGenres,
      status: _selectedStatus,
      minRating: _minRating > 0 ? _minRating : null,
      sortBy: _sortBy,
    );
  }

  void setQuery(String newQuery) {
    _query = newQuery;
    notifyListeners();
  }

  void toggleGenre(String genre) {
    if (_selectedGenres.contains(genre)) {
      _selectedGenres.remove(genre);
    } else {
      _selectedGenres.add(genre);
    }
    notifyListeners();
  }

  void setStatus(String? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setMinRating(double rating) {
    _minRating = rating;
    notifyListeners();
  }

  void setSortBy(MangaSortBy sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void resetFilters() {
    _selectedGenres = [];
    _selectedStatus = null;
    _minRating = 0.0;
    _sortBy = MangaSortBy.ratingDesc;
    notifyListeners();
  }
}
