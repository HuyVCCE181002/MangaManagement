import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/services.dart';
import '../widgets/manga_card.dart';
import 'detail_screen.dart';
import 'form_screen.dart';
import 'genre_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final MangaService _service = MangaService.instance;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Manga> _allMangas = [];
  String _searchQuery = '';
  String _selectedGenre = 'Tất cả';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMangas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMangas() async {
    setState(() => _isLoading = true);
    final list = await _service.getMangas();
    setState(() {
      _allMangas = list;
      _isLoading = false;
    });
  }

  List<Manga> get _filteredMangas {
    return _allMangas.where((m) {
      final matchesSearch = m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre = _selectedGenre == 'Tất cả' || m.genre == _selectedGenre;
      return matchesSearch && matchesGenre;
    }).toList();
  }

  List<Manga> get _favoriteMangas {
    return _filteredMangas.where((m) => m.isFavorite).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayMangas = _filteredMangas;
    final displayFavorites = _favoriteMangas;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFFA29BFE)),
            SizedBox(width: 8),
            Text(
              'Manga Vault',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quản lý thể loại',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const GenreListScreen()),
              );
              if (!mounted) return;
              setState(() {
                if (!MangaService.genres.contains(_selectedGenre)) {
                  _selectedGenre = 'Tất cả';
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C5CE7),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Tất cả (${displayMangas.length})'),
            Tab(text: 'Yêu thích (${displayFavorites.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm truyện theo tên hoặc tác giả...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E212D),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Bộ lọc thể loại dạng cuộn ngang
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: MangaService.genres.length,
              itemBuilder: (context, index) {
                final genre = MangaService.genres[index];
                final isSelected = _selectedGenre == genre;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(genre),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C5CE7),
                    backgroundColor: const Color(0xFF1E212D),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedGenre = genre),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Nội dung 2 tab
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Tất cả truyện
                      _buildMangaList(
                        displayMangas,
                        emptyMessage: 'Không tìm thấy truyện nào phù hợp.',
                      ),
                      // Tab 2: Danh sách yêu thích
                      _buildMangaList(
                        displayFavorites,
                        emptyMessage: 'Chưa có bộ truyện nào trong danh sách yêu thích.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Thêm Truyện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const MangaFormScreen()),
          );
          if (added == true) {
            _loadMangas();
          }
        },
      ),
    );
  }

  Widget _buildMangaList(List<Manga> mangas, {required String emptyMessage}) {
    if (mangas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMangas,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: mangas.length,
        itemBuilder: (context, index) {
          final manga = mangas[index];
          return MangaCard(
            manga: manga,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MangaDetailScreen(mangaId: manga.id),
                ),
              );
              if (changed == true) {
                _loadMangas();
              }
            },
            onFavoriteToggle: () async {
              await _service.toggleFavorite(manga.id);
              _loadMangas();
            },
          );
        },
      ),
    );
  }
}
