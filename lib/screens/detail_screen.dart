import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../services/auth_guard.dart';
import '../services/auth_service.dart';
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
  final AuthService _auth = AuthService.instance;
  Manga? _manga;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _loadManga();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _loadManga() {
    setState(() {
      _manga = _service.getMangaById(widget.mangaId);
    });
  }

  void _showDeleteDialog(BuildContext context, Manga manga) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE)),
        ),
        title: Text(
          'Xác nhận xóa (Dành cho Admin)',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bộ truyện "${manga.title}" khỏi hệ thống?',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await _service.deleteManga(manga.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Xóa Truyện'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_manga == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy thông tin truyện')),
      );
    }

    final manga = _manga!;
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(manga.title),
        actions: [
          // Nút yêu thích: Guest bấm vào sẽ bắt đăng nhập
          IconButton(
            tooltip: 'Yêu thích',
            icon: Icon(
              manga.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: manga.isFavorite ? Colors.redAccent : theme.colorScheme.onSurface,
            ),
            onPressed: () async {
              final canFav = await AuthGuard.checkPermission(
                context,
                featureName: 'Lưu truyện yêu thích',
                minRole: UserRole.reader,
              );
              if (!canFav) return;

              await _service.toggleFavorite(manga.id);
              _loadManga();
            },
          ),

          // Nút Chỉnh sửa: Dành cho Staff và Admin
          if (currentUser.role.canEditManga)
            IconButton(
              tooltip: 'Chỉnh sửa (Staff / Admin)',
              icon: const Icon(Icons.edit_rounded),
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

          // Nút Xóa: Chỉ dành riêng cho Admin
          if (currentUser.role.canDeleteManga)
            IconButton(
              tooltip: 'Xóa truyện (Chỉ Admin)',
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              onPressed: () => _showDeleteDialog(context, manga),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // Ảnh bìa
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      manga.coverUrl,
                      height: 260,
                      width: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 260,
                        width: 180,
                        color: isDark ? const Color(0xFF222634) : const Color(0xFFE0E0E0),
                        child: const Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tên truyện và tác giả
              Center(
                child: Text(
                  manga.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Tác giả: ${manga.author}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
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
              const SizedBox(height: 24),

              // Thẻ tiến độ đọc truyện
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tiến độ đọc truyện',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${(manga.progressPercentage * 100).toInt()}% Hoàn thành',
                          style: const TextStyle(
                            color: Color(0xFF6C5CE7),
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
                        backgroundColor: isDark ? const Color(0xFF222634) : const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chap ${manga.currentChapter} / ${manga.totalChapters}',
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: manga.currentChapter > 0
                                  ? () async {
                                      // Kiểm tra quyền lưu tiến độ đọc truyện (Guest bắt đăng nhập)
                                      final canTrack = await AuthGuard.checkPermission(
                                        context,
                                        featureName: 'Lưu tiến độ đọc truyện',
                                        minRole: UserRole.reader,
                                      );
                                      if (!canTrack) return;

                                      await _service.updateChapter(manga.id, manga.currentChapter - 1);
                                      _loadManga();
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              onPressed: manga.currentChapter < manga.totalChapters
                                  ? () async {
                                      // Kiểm tra quyền lưu tiến độ đọc truyện (Guest bắt đăng nhập)
                                      final canTrack = await AuthGuard.checkPermission(
                                        context,
                                        featureName: 'Lưu tiến độ đọc truyện',
                                        minRole: UserRole.reader,
                                      );
                                      if (!canTrack) return;

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
              const SizedBox(height: 24),

              // Tóm tắt nội dung
              Text(
                'Tóm tắt nội dung',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                manga.description.isNotEmpty
                    ? manga.description
                    : 'Chưa có thông tin mô tả cho bộ truyện này.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.6, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
