import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/favorites_reviews/domain/repositories/user_interaction_repository.dart';
import 'features/favorites_reviews/presentation/providers/favorites_provider.dart';
import 'features/manga/domain/repositories/manga_repository.dart';
import 'features/manga/presentation/providers/manga_provider.dart';
import 'features/search_filter/presentation/providers/search_filter_provider.dart';
import 'main_screen.dart';

class MangaApp extends StatelessWidget {
  final MangaRepository mangaRepository;
  final UserInteractionRepository userInteractionRepository;

  const MangaApp({
    super.key,
    required this.mangaRepository,
    required this.userInteractionRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MangaProvider(repository: mangaRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(repository: userInteractionRepository)..loadFavorites(),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchFilterProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}
