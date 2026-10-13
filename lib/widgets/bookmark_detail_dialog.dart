import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/database_helper.dart';
import '../screens/chapter_reader_screen.dart';

class BookmarkDetailDialog extends StatelessWidget {
  final BookmarkDetail detail;
  final VoidCallback onBookmarkDeleted;

  const BookmarkDetailDialog({
    super.key,
    required this.detail,
    required this.onBookmarkDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E212A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    detail.coverUrl,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 120,
                      color: Colors.grey,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.mangaTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chương ${detail.chapterNumber}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail.chapterTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await DatabaseHelper.instance.deleteBookmark(detail.bookmark.userId, detail.bookmark.mangaId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        onBookmarkDeleted();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Đi tới', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                       Navigator.pop(context); // Đóng dialog

                       // Lấy thông tin chapter để navigate
                       final chapter = await DatabaseHelper.instance.getChapterById(detail.bookmark.chapterId);
                       final allChapters = await DatabaseHelper.instance.getChaptersByMangaId(detail.bookmark.mangaId);

                       if (chapter != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChapterReaderScreen(
                                chapter: chapter,
                                allChapters: allChapters,
                              ),
                            ),
                          );
                       }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
