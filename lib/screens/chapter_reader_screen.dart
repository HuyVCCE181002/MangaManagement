import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'chapter_form_screen.dart';

class ChapterReaderScreen extends StatefulWidget {
  final Chapter chapter;
  final List<Chapter> allChapters;

  const ChapterReaderScreen({
    super.key,
    required this.chapter,
    this.allChapters = const [],
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late Chapter _currentChapter;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _currentIndex {
    return widget.allChapters.indexWhere((c) => c.id == _currentChapter.id);
  }

  Chapter? get _prevChapter {
    final idx = _currentIndex;
    if (idx > 0) return widget.allChapters[idx - 1];
    return null;
  }

  Chapter? get _nextChapter {
    final idx = _currentIndex;
    if (idx != -1 && idx < widget.allChapters.length - 1) {
      return widget.allChapters[idx + 1];
    }
    return null;
  }

  void _goToChapter(Chapter target) {
    setState(() {
      _currentChapter = target;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = AuthService.instance.currentUser;
    final isStaff = currentUser.role == UserRole.staff;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10121A) : const Color(0xFFF0F2F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chap ${_currentChapter.chapterNumber}: ${_currentChapter.title}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentChapter.contents.length} trang ảnh ${isStaff ? "• Chế độ Staff" : ""}',
              style: TextStyle(
                fontSize: 12,
                color: isStaff ? const Color(0xFF0984E3) : theme.colorScheme.onSurfaceVariant,
                fontWeight: isStaff ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Nút Edit chương trực tiếp cho Staff
          if (currentUser.role.canEditChapter)
            IconButton(
              tooltip: 'Chỉnh sửa chương này (Staff)',
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0984E3)),
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChapterFormScreen(
                      mangaId: _currentChapter.mangaId,
                      initialChapter: _currentChapter,
                    ),
                  ),
                );
                if (updated == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: _currentChapter.contents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chương này chưa có trang hình ảnh nào.',
                    style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _currentChapter.contents.length + 1, // +1 for footer navigation
              itemBuilder: (context, index) {
                if (index == _currentChapter.contents.length) {
                  // Thanh điều hướng Previous/Next Chapter ở cuối trang
                  return _buildBottomChapterNav(theme, isDark);
                }

                final imageUrl = _currentChapter.contents[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        final total = loadingProgress.expectedTotalBytes;
                        final loaded = loadingProgress.cumulativeBytesLoaded;
                        final percent = (total != null && total > 0) ? (loaded / total) : null;
                        return Container(
                          height: 380,
                          color: isDark ? const Color(0xFF161922) : const Color(0xFFE8EBF2),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    value: percent,
                                    strokeWidth: 2.5,
                                    color: const Color(0xFF6C5CE7),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Đang tải trang ${index + 1}...',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 240,
                        color: isDark ? const Color(0xFF1E212D) : const Color(0xFFEDE9FE),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Không tải được trang ${index + 1}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                imageUrl,
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBottomChapterNav(ThemeData theme, bool isDark) {
    final prev = _prevChapter;
    final next = _nextChapter;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Text(
                '— Hết Chương ${_currentChapter.chapterNumber} —',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardColor,
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        prev != null ? 'Chap ${prev.chapterNumber}' : 'Đầu truyện',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: prev != null ? () => _goToChapter(prev) : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: Text(
                        next != null ? 'Chap ${next.chapterNumber}' : 'Chương mới nhất',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      onPressed: next != null ? () => _goToChapter(next) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
