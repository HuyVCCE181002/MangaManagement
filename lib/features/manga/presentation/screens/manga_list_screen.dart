import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/entities/manga.dart';
import '../providers/manga_provider.dart';
import '../widgets/manga_card.dart';
import '../widgets/star_rating_bar.dart';
import 'manga_detail_screen.dart';
import 'manga_form_screen.dart';

class MangaListScreen extends StatefulWidget {
  const MangaListScreen({super.key});

  @override
  State<MangaListScreen> createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen> {
  bool _isGridView = true;
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Đang ra, 2: Hoàn thành

  final List<String> _filterTabs = ['Tất cả', 'Đang phát hành', 'Đã hoàn thành'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MangaProvider>().loadMangas();
    });
  }

  List<Manga> _getFilteredMangas(List<Manga> allMangas) {
    if (_selectedFilterIndex == 1) {
      return allMangas.where((m) => m.status.toLowerCase() == 'ongoing').toList();
    } else if (_selectedFilterIndex == 2) {
      return allMangas.where((m) => m.status.toLowerCase() == 'completed').toList();
    }
    return allMangas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Manga Vault'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: _isGridView ? 'Xem dạng danh sách' : 'Xem dạng lưới',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Consumer<MangaProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.mangas.isEmpty) {
            return const LoadingIndicator(message: 'Đang tải kho truyện tranh...');
          }

          if (provider.errorMessage != null && provider.mangas.isEmpty) {
            return ErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.loadMangas(),
            );
          }

          final displayMangas = _getFilteredMangas(provider.mangas);

          return RefreshIndicator(
            color: AppColors.primaryLight,
            backgroundColor: AppColors.surface,
            onRefresh: () => provider.refresh(),
            child: CustomScrollView(
              slivers: [
                // Featured Banner (Bộ truyện nổi bật nhất)
                if (provider.mangas.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedMangaBanner(provider.mangas.first),
                  ),

                // Filter Tabs Bar & Counter
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(_filterTabs.length, (index) {
                              final isSelected = _selectedFilterIndex == index;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_filterTabs[index]),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.surfaceVariant,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedFilterIndex = index);
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                        Text(
                          '${displayMangas.length} bộ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content List or Grid
                if (displayMangas.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.menu_book_outlined,
                      title: 'Chưa có truyện nào trong mục này',
                      description: 'Hãy bấm vào nút dấu cộng bên dưới để thêm truyện mới vào thư viện.',
                      actionLabel: 'Thêm truyện ngay',
                      onAction: () => _navigateToCreateScreen(context),
                    ),
                  )
                else if (_isGridView)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final manga = displayMangas[index];
                          return MangaCard(
                            manga: manga,
                            isGrid: true,
                            onTap: () => _navigateToDetailScreen(context, manga.id),
                          );
                        },
                        childCount: displayMangas.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final manga = displayMangas[index];
                          return MangaCard(
                            manga: manga,
                            isGrid: false,
                            onTap: () => _navigateToDetailScreen(context, manga.id),
                          );
                        },
                        childCount: displayMangas.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateScreen(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm Truyện', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildFeaturedMangaBanner(Manga featured) {
    return GestureDetector(
      onTap: () => _navigateToDetailScreen(context, featured.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              featured.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: AppColors.surfaceVariant),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TRUYỆN NỔI BẬT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    featured.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StarRatingBar(rating: featured.rating, starSize: 14),
                      const SizedBox(width: 8),
                      Text(
                        '• ${featured.genres.take(2).join(', ')}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đang đọc: Chap ${featured.currentChapter}/${featured.totalChapters}',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetailScreen(BuildContext context, String mangaId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(mangaId: mangaId),
      ),
    );
  }

  void _navigateToCreateScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MangaFormScreen(),
      ),
    );
  }
}
