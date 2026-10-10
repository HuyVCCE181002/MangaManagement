import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../manga/presentation/providers/manga_provider.dart';
import '../../../manga/presentation/screens/manga_detail_screen.dart';
import '../../../manga/presentation/widgets/manga_card.dart';
import '../providers/favorites_provider.dart';
import '../widgets/favorite_button.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ Sưu Tập Yêu Thích'),
      ),
      body: Consumer2<MangaProvider, FavoritesProvider>(
        builder: (context, mangaProvider, favProvider, child) {
          final favoriteMangas = mangaProvider.mangas
              .where((m) => favProvider.isFavorite(m.id))
              .toList();

          if (favoriteMangas.isEmpty) {
            return const EmptyStateView(
              icon: Icons.favorite_border_rounded,
              title: 'Chưa có truyện yêu thích',
              description:
                  'Khám phá thư viện và bấm vào biểu tượng trái tim để lưu trữ những bộ truyện bạn yêu thích nhất.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: AppColors.favorite,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Đang theo dõi ${favoriteMangas.length} bộ truyện',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: favoriteMangas.length,
                  itemBuilder: (context, index) {
                    final manga = favoriteMangas[index];
                    return MangaCard(
                      manga: manga,
                      isGrid: false,
                      trailing: FavoriteButton(mangaId: manga.id),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MangaDetailScreen(mangaId: manga.id),
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
