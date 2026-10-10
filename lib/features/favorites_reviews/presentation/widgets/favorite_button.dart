import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/favorites_provider.dart';

class FavoriteButton extends StatelessWidget {
  final String mangaId;
  final double size;
  final bool showBackground;

  const FavoriteButton({
    super.key,
    required this.mangaId,
    this.size = 24,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favProvider, child) {
        final isFav = favProvider.isFavorite(mangaId);

        final iconButton = IconButton(
          icon: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? AppColors.favorite : AppColors.textPrimary,
            size: size,
          ),
          onPressed: () async {
            final nowFav = await favProvider.toggleFavorite(mangaId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    nowFav
                        ? 'Đã thêm vào danh sách Yêu thích ❤️'
                        : 'Đã xóa khỏi danh sách Yêu thích',
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: nowFav ? AppColors.primaryDark : AppColors.surfaceVariant,
                ),
              );
            }
          },
        );

        if (showBackground) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: iconButton,
          );
        }

        return iconButton;
      },
    );
  }
}
