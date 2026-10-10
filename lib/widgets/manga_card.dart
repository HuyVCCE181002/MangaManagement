import 'package:flutter/material.dart';
import '../models/manga.dart';

class MangaCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E3440), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh bìa
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  manga.coverUrl,
                  width: 76,
                  height: 105,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 76,
                    height: 105,
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Thông tin truyện
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            manga.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Nút yêu thích
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            manga.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: manga.isFavorite ? Colors.redAccent : Colors.grey,
                            size: 22,
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tác giả: ${manga.author}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),

                    // Badge thể loại và trạng thái
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            manga.genre,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA29BFE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: manga.status == 'Ongoing'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            manga.status == 'Ongoing' ? 'Đang ra' : 'Hoàn thành',
                            style: TextStyle(
                              fontSize: 11,
                              color: manga.status == 'Ongoing' ? Colors.greenAccent : Colors.lightBlueAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              manga.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tiến độ đọc
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: manga.progressPercentage,
                              backgroundColor: Colors.grey[800],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${manga.currentChapter}/${manga.totalChapters} chap',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
