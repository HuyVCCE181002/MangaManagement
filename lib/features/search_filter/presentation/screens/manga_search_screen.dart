import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../manga/domain/entities/manga.dart';
import 'package:manga_management_app/features/manga/domain/entities/manga_filter.dart';
import '../../../manga/presentation/providers/manga_provider.dart';
import '../../../manga/presentation/screens/manga_detail_screen.dart';
import '../../../manga/presentation/widgets/manga_card.dart';
import '../providers/search_filter_provider.dart';
import '../widgets/filter_bottom_sheet.dart';

class MangaSearchScreen extends StatefulWidget {
  const MangaSearchScreen({super.key});

  @override
  State<MangaSearchScreen> createState() => _MangaSearchScreenState();
}

class _MangaSearchScreenState extends State<MangaSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Manga> _filterMangas(List<Manga> all, SearchFilterProvider filter) {
    var result = List<Manga>.from(all);

    // Filter Query
    if (filter.query.isNotEmpty) {
      final q = filter.query.toLowerCase();
      result = result.where((m) {
        return m.title.toLowerCase().contains(q) ||
            (m.originalTitle?.toLowerCase().contains(q) ?? false) ||
            m.author.toLowerCase().contains(q);
      }).toList();
    }

    // Filter Genres
    if (filter.selectedGenres.isNotEmpty) {
      result = result.where((m) {
        return filter.selectedGenres.any((g) => m.genres.contains(g));
      }).toList();
    }

    // Filter Status
    if (filter.selectedStatus != null && filter.selectedStatus!.isNotEmpty) {
      result = result.where((m) => m.status == filter.selectedStatus).toList();
    }

    // Filter Rating
    if (filter.minRating > 0) {
      result = result.where((m) => m.rating >= filter.minRating).toList();
    }

    // Sort
    switch (filter.sortBy) {
      case MangaSortBy.ratingDesc:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case MangaSortBy.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case MangaSortBy.chaptersDesc:
        result.sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
        break;
      case MangaSortBy.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm Kiếm & Khám Phá'),
      ),
      body: Consumer2<MangaProvider, SearchFilterProvider>(
        builder: (context, mangaProvider, filterProvider, child) {
          final searchResults = _filterMangas(mangaProvider.mangas, filterProvider);

          return Column(
            children: [
              // Search Bar & Filter Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => filterProvider.setQuery(val),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên truyện, tác giả...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    filterProvider.setQuery('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Stack(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.tune_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: filterProvider.hasActiveFilter
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            foregroundColor: filterProvider.hasActiveFilter
                                ? Colors.white
                                : AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (ctx) => const FractionallySizedBox(
                                heightFactor: 0.85,
                                child: FilterBottomSheet(),
                              ),
                            );
                          },
                        ),
                        if (filterProvider.hasActiveFilter)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active Filters indicator chip bar
              if (filterProvider.hasActiveFilter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Đang áp dụng bộ lọc',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => filterProvider.resetFilters(),
                        child: const Text(
                          'Xóa tất cả',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Result Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Tìm thấy ${searchResults.length} kết quả',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Result List
              Expanded(
                child: searchResults.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'Không tìm thấy truyện phù hợp',
                        description:
                            'Hãy thử thay đổi từ khóa hoặc điều chỉnh lại các tiêu chí trong bộ lọc nâng cao.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final manga = searchResults[index];
                          return MangaCard(
                            manga: manga,
                            isGrid: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MangaDetailScreen(mangaId: manga.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
