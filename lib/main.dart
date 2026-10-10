import 'package:flutter/material.dart';
import 'app.dart';
import 'core/storage/local_storage_service.dart';
import 'features/favorites_reviews/data/datasources/user_interaction_local_datasource.dart';
import 'features/favorites_reviews/data/repositories/user_interaction_repository_impl.dart';
import 'features/manga/data/datasources/manga_local_datasource.dart';
import 'features/manga/data/datasources/manga_remote_datasource.dart';
import 'features/manga/data/repositories/manga_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Local Storage Service (SharedPreferences)
  final storageService = await LocalStorageService.init();

  // Khởi tạo DataSources và Repositories cho Manga Feature
  final mangaRemoteDataSource = MangaRemoteDataSourceImpl();
  final mangaLocalDataSource = MangaLocalDataSourceImpl(storageService);
  final mangaRepository = MangaRepositoryImpl(
    remoteDataSource: mangaRemoteDataSource,
    localDataSource: mangaLocalDataSource,
  );

  // Khởi tạo DataSources và Repositories cho Favorites & Reviews Feature
  final userInteractionLocalDataSource = UserInteractionLocalDataSourceImpl(storageService);
  final userInteractionRepository = UserInteractionRepositoryImpl(
    localDataSource: userInteractionLocalDataSource,
  );

  runApp(
    MangaApp(
      mangaRepository: mangaRepository,
      userInteractionRepository: userInteractionRepository,
    ),
  );
}
