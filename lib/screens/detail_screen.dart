import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../services/services.dart';
import 'form_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final String mangaId;

  const MangaDetailScreen({super.key, required this.mangaId});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final MangaService _service = MangaService.instance;
  Manga? _manga;

  @override
  void initState() {
    super.initState();
    _loadManga();
  }

  void _loadManga() {
    setState(() {
      _manga = _service.getMangaById(widget.mangaId);
    });
  }

  void _showDeleteDialog(BuildContext context, Manga manga) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${manga.title}" khỏi danh sách?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _service.deleteManga(manga.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_manga == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy thông tin truyện')),
      );
    }

    final manga = _manga!;

    return Scaffold(
      appBar: AppBar(
        title: Text(manga.title),
        actions: [
          IconButton(
            icon: Icon(
              manga.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: manga.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: () async {
              await _service.toggleFavorite(manga.id);
              _loadManga();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MangaFormScreen(initialManga: manga),
                ),
              );
              if (updated == true) {
                _loadManga();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _showDeleteDialog(context, manga),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ảnh bìa
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                manga.coverUrl,
                height: 240,
                width: 170,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 240,
                  width: 170,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tên truyện và tác giả
          Center(
            child: Text(
              manga.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Tác giả: ${manga.author}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Hàng badge thông tin
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(manga.genre, const Color(0xFF6C5CE7)),
              const SizedBox(width: 8),
              _buildBadge(
                manga.status == 'Ongoing' ? 'Đang ra' : 'Hoàn thành',
                manga.status == 'Ongoing' ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildBadge('★ ${manga.rating}', Colors.amber[800]!),
            ],
          ),
          const SizedBox(height: 20),

          // Thẻ tiến độ đọc truyện
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E3440)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiến độ đọc truyện',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${(manga.progressPercentage * 100).toInt()}% Hoàn thành',
                      style: const TextStyle(
                        color: Color(0xFFA29BFE),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: manga.progressPercentage,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chap ${manga.currentChapter} / ${manga.totalChapters}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: manga.currentChapter > 0
                              ? () async {
                                  await _service.updateChapter(manga.id, manga.currentChapter - 1);
                                  _loadManga();
                                }
                              : null,
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          onPressed: manga.currentChapter < manga.totalChapters
                              ? () async {
                                  await _service.updateChapter(manga.id, manga.currentChapter + 1);
                                  _loadManga();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tóm tắt nội dung
          const Text(
            'Tóm tắt nội dung',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            manga.description.isNotEmpty
                ? manga.description
                : 'Chưa có thông tin mô tả cho bộ truyện này.',
            style: const TextStyle(color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
