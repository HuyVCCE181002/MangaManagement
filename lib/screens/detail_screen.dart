import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../models/user.dart';
import '../services/auth_guard.dart';
import '../services/auth_service.dart';
import '../services/chapter_service.dart';
import '../services/notification_server_service.dart';
import '../services/services.dart';
import '../services/wallet_service.dart';
import 'chapter_form_screen.dart';
import 'chapter_reader_screen.dart';
import 'form_screen.dart';
import 'wallet_screen.dart';

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
  List<Chapter> _chapters = [];
  Set<String> _purchasedChapterIds = {};
  bool _isLoadingChapters = true;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _loadManga();
    _loadChapters();
  }

  void _onAuthChanged() {
    if (mounted) {
      _loadChapters();
      setState(() {});
    }
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

  Future<void> _loadChapters() async {
    final user = _auth.currentUser;
    final chaptersFuture = ChapterService.instance.getChapters(
      widget.mangaId,
      forceRefresh: true,
    );
    final purchasedFuture = !user.isGuest
        ? ChapterService.instance.getPurchasedChapterIds(
            user.id,
            forceRefresh: true,
          )
        : Future.value(<String>{});

    final results = await Future.wait([chaptersFuture, purchasedFuture]);

    if (mounted) {
      setState(() {
        _chapters = results[0] as List<Chapter>;
        _purchasedChapterIds = results[1] as Set<String>;
        _isLoadingChapters = false;
      });
    }
  }

  /// Xử lý mua và mở khóa chương phía người dùng
  Future<void> _handlePurchaseChapter(
    BuildContext context,
    Chapter chapter,
  ) async {
    final canBuy = await AuthGuard.checkPermission(
      context,
      featureName: 'Mua và mở khóa chương truyện',
      minRole: UserRole.reader,
    );
    if (!canBuy) return;

    if (!context.mounted) return;

    final user = _auth.currentUser;
    // Đồng bộ số dư ví mới nhất của user
    await WalletService.instance.loadWallet(user.id);
    if (!context.mounted) return;

    final wallet = WalletService.instance;
    final int requiredCoins = chapter.price.toInt();
    final bool hasEnoughCoins =
        requiredCoins <= 0 || wallet.balance >= requiredCoins;
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF6C5CE7),
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Xác nhận mua chương',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có muốn mở khóa Chương ${chapter.chapterNumber}: "${chapter.title}"?',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE17055).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE17055).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFE17055),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Giá: $requiredCoins xu',
                    style: const TextStyle(
                      color: Color(0xFFE17055),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEnoughCoins
                    ? const Color(0xFF00B894).withValues(alpha: 0.08)
                    : const Color(0xFFD63031).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasEnoughCoins
                      ? const Color(0xFF00B894).withValues(alpha: 0.3)
                      : const Color(0xFFD63031).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasEnoughCoins
                            ? Icons.account_balance_wallet_rounded
                            : Icons.warning_amber_rounded,
                        color: hasEnoughCoins
                            ? const Color(0xFF00B894)
                            : const Color(0xFFD63031),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Số dư hiện có:',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${wallet.balance} xu',
                    style: TextStyle(
                      color: hasEnoughCoins
                          ? const Color(0xFF00B894)
                          : const Color(0xFFD63031),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasEnoughCoins) ...[
              const SizedBox(height: 8),
              Text(
                'Số dư không đủ! Bạn còn thiếu ${requiredCoins - wallet.balance} xu để mở khóa chương này.',
                style: const TextStyle(
                  color: Color(0xFFD63031),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          if (!hasEnoughCoins)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Nạp Thêm Coins',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(ctx, false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Xác nhận mua',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final unlockResult = await WalletService.instance.unlockChapter(
        userId: user.id,
        chapterId: chapter.id,
      );

      if (!unlockResult.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(unlockResult.message),
              backgroundColor: const Color(0xFFD63031),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await ChapterService.instance.getPurchasedChapterIds(
        user.id,
        forceRefresh: true,
      );
      await _loadChapters();

      // Bắn thông báo Mua chương thành công qua WebSocket
      NotificationServerService.instance.notifyChapterPurchased(
        userId: user.id,
        mangaTitle: _manga?.title ?? 'Truyện',
        chapterNumber: chapter.chapterNumber,
        coinsSpent: requiredCoins,
        chapterId: chapter.id,
        mangaId: widget.mangaId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Đã mở khóa thành công Chương ${chapter.chapterNumber}! (Đã trừ $requiredCoins xu)',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00B894),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Xác nhận xóa chương (Delete Chapter) dành cho Staff
  Future<void> _confirmDeleteChapter(
    BuildContext context,
    Chapter chapter,
  ) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Xác nhận xóa chương',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa Chương ${chapter.chapterNumber}: "${chapter.title}" khỏi hệ thống?',
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD63031),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Xóa chương'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ChapterService.instance.softDeleteChapter(
          widget.mangaId,
          chapter.id,
        );
        await _loadChapters();

        // Bắn thông báo Staff xóa chương thành công
        NotificationServerService.instance.notifyStaffChapterAction(
          staffId: _auth.currentUser.id,
          action: 'delete',
          isSuccess: true,
          mangaTitle: _manga?.title ?? 'Truyện',
          chapterNumber: chapter.chapterNumber,
          mangaId: widget.mangaId,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã xóa thành công Chương ${chapter.chapterNumber}!',
              ),
              backgroundColor: const Color(0xFF00B894),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        // Bắn thông báo Staff xóa chương thất bại
        NotificationServerService.instance.notifyStaffChapterAction(
          staffId: _auth.currentUser.id,
          action: 'delete',
          isSuccess: false,
          mangaTitle: _manga?.title ?? 'Truyện',
          chapterNumber: chapter.chapterNumber,
          errorDetails: e.toString(),
          mangaId: widget.mangaId,
        );
      }
    }
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
          side: BorderSide(
            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
          ),
        ),
        title: Text(
          'Xác nhận xóa (Dành cho Admin)',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
              manga.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: manga.isFavorite
                  ? Colors.redAccent
                  : theme.colorScheme.onSurface,
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

          // Staff có thể ẩn/hiện khỏi danh sách; xóa vĩnh viễn vẫn chỉ dành cho Admin.
          if (currentUser.role.canEditManga)
            IconButton(
              tooltip: manga.isHidden ? 'Hiện truyện' : 'Ẩn truyện',
              icon: Icon(
                manga.isHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () async {
                await _service.setMangaHidden(manga.id, !manga.isHidden);
                _loadManga();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      manga.isHidden
                          ? 'Đã hiện truyện.'
                          : 'Đã ẩn truyện khỏi độc giả.',
                    ),
                  ),
                );
              },
            ),

          // Xóa vĩnh viễn: Chỉ dành riêng cho Admin.
          if (currentUser.role.canDeleteManga)
            IconButton(
              tooltip: 'Xóa truyện (Chỉ Admin)',
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
              ),
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
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.15,
                        ),
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
                        color: isDark
                            ? const Color(0xFF222634)
                            : const Color(0xFFE0E0E0),
                        child: const Icon(
                          Icons.broken_image_rounded,
                          size: 50,
                          color: Colors.grey,
                        ),
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
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
                    color: isDark
                        ? const Color(0xFF2E3440)
                        : const Color(0xFFE2E5EE),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
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
                        backgroundColor: isDark
                            ? const Color(0xFF222634)
                            : const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6C5CE7),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chap ${manga.currentChapter} / ${manga.totalChapters}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: manga.currentChapter > 0
                                  ? () async {
                                      // Kiểm tra quyền lưu tiến độ đọc truyện (Guest bắt đăng nhập)
                                      final canTrack =
                                          await AuthGuard.checkPermission(
                                            context,
                                            featureName:
                                                'Lưu tiến độ đọc truyện',
                                            minRole: UserRole.reader,
                                          );
                                      if (!canTrack) return;

                                      await _service.updateChapter(
                                        manga.id,
                                        manga.currentChapter - 1,
                                      );
                                      _loadManga();
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                              ),
                              icon: const Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed:
                                  manga.currentChapter < manga.totalChapters
                                  ? () async {
                                      // Kiểm tra quyền lưu tiến độ đọc truyện (Guest bắt đăng nhập)
                                      final canTrack =
                                          await AuthGuard.checkPermission(
                                            context,
                                            featureName:
                                                'Lưu tiến độ đọc truyện',
                                            minRole: UserRole.reader,
                                          );
                                      if (!canTrack) return;

                                      await _service.updateChapter(
                                        manga.id,
                                        manga.currentChapter + 1,
                                      );
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                manga.description.isNotEmpty
                    ? manga.description
                    : 'Chưa có thông tin mô tả cho bộ truyện này.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),

              // Danh sách chương (Chapters)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Danh Sách Chương (${_chapters.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (currentUser.role.canCreateChapter)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Thêm Chương',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () async {
                            final maxChap = _chapters.isEmpty
                                ? 0
                                : _chapters
                                      .map((c) => c.chapterNumber)
                                      .reduce((a, b) => a > b ? a : b);
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChapterFormScreen(
                                  mangaId: widget.mangaId,
                                  suggestedChapterNumber: maxChap + 1,
                                ),
                              ),
                            );
                            if (updated == true) {
                              _loadChapters();
                            }
                          },
                        ),
                      if (currentUser.role.canEditChapter &&
                          !currentUser.role.canCreateChapter)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0984E3,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF0984E3,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: Color(0xFF0984E3),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Quyền Nhân Viên',
                                style: TextStyle(
                                  color: Color(0xFF0984E3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isLoadingChapters)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_chapters.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3440)
                          : const Color(0xFFE2E5EE),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Chưa có chương nào được xuất bản cho truyện này.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chapters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chapter = _chapters[index];
                    return _buildChapterItem(
                      context,
                      chapter,
                      currentUser,
                      theme,
                      isDark,
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterItem(
    BuildContext context,
    Chapter chapter,
    AppUser currentUser,
    ThemeData theme,
    bool isDark,
  ) {
    // Kiểm tra trạng thái mở khóa cho người dùng hiện tại
    final bool isPurchasedByMe = _purchasedChapterIds.contains(chapter.id);
    final bool isStaffOrAdmin =
        currentUser.role == UserRole.staff ||
        currentUser.role == UserRole.admin;
    final bool isUnlocked =
        !chapter.isLocked ||
        chapter.price <= 0 ||
        isPurchasedByMe ||
        isStaffOrAdmin;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Bấm vào chương để xem nội dung (View Chapter List / Reader)
          onTap: () {
            if (isUnlocked) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChapterReaderScreen(
                    chapter: chapter,
                    allChapters: _chapters,
                  ),
                ),
              );
            } else {
              _handlePurchaseChapter(context, chapter);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Badge số thứ tự chap
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${chapter.chapterNumber}',
                    style: const TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Thông tin tiêu đề & số trang ảnh
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title.isNotEmpty
                            ? chapter.title
                            : 'Chương ${chapter.chapterNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${chapter.contents.length} trang ảnh',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          // Badge Giá nếu có phí
                          if (chapter.price > 0)
                            _buildBadge(
                              '${chapter.price.toInt()} xu',
                              const Color(0xFFE17055),
                            ),
                          // Badge trạng thái khóa / mở khóa theo User
                          if (chapter.isLocked) ...[
                            if (isPurchasedByMe)
                              _buildBadge(
                                'Đã mua (Mở khóa)',
                                const Color(0xFF00B894),
                              )
                            else if (isStaffOrAdmin)
                              _buildBadge(
                                'Khóa (${currentUser.role.label})',
                                Colors.deepOrange,
                              )
                            else
                              _buildBadge('Đang khóa', Colors.deepOrange),
                          ] else
                            _buildBadge('Miễn phí', const Color(0xFF00B894)),
                        ],
                      ),
                    ],
                  ),
                ),

                // NÚT MUA CHƯƠNG: Dành cho Độc giả khi chương bị khóa và chưa mua
                if (!isUnlocked)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE17055),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 15),
                      label: Text(
                        chapter.price > 0
                            ? 'Mua ${chapter.price.toInt()} xu'
                            : 'Mở khóa',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _handlePurchaseChapter(context, chapter),
                    ),
                  ),

                // CHỨC NĂNG EDIT CHƯƠNG: Dành cho Staff
                if (currentUser.role.canEditChapter)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      tooltip: 'Chỉnh sửa chương (Staff)',
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF0984E3),
                        size: 22,
                      ),
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChapterFormScreen(
                              mangaId: widget.mangaId,
                              initialChapter: chapter,
                            ),
                          ),
                        );
                        if (updated == true) {
                          _loadChapters();
                        }
                      },
                    ),
                  ),

                // CHỨC NĂNG XÓA CHƯƠNG: Dành cho Staff
                if (currentUser.role.canDeleteChapter)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: IconButton(
                      tooltip: 'Xóa chương (Staff)',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _confirmDeleteChapter(context, chapter),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
