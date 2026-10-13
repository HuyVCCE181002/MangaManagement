import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chapter.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/chapter_service.dart';

class ChapterFormScreen extends StatefulWidget {
  final String mangaId;
  final Chapter? initialChapter;
  final int? suggestedChapterNumber;

  const ChapterFormScreen({
    super.key,
    required this.mangaId,
    this.initialChapter,
    this.suggestedChapterNumber,
  });

  @override
  State<ChapterFormScreen> createState() => _ChapterFormScreenState();
}

class _ChapterFormScreenState extends State<ChapterFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _chapterNumberController;
  late TextEditingController _priceController;
  late TextEditingController _newImageUrlController;

  late bool _isLocked;
  late List<String> _contents;
  bool _isLoading = false;
  String? _contentsError;

  bool get _isEditing => widget.initialChapter != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialChapter;
    _titleController = TextEditingController(text: c?.title ?? '');
    _chapterNumberController = TextEditingController(
      text: c != null ? c.chapterNumber.toString() : (widget.suggestedChapterNumber?.toString() ?? '1'),
    );
    _priceController = TextEditingController(
      text: c != null ? (c.price > 0 ? c.price.toStringAsFixed(0) : '0') : '0',
    );
    _newImageUrlController = TextEditingController();

    _isLocked = c?.isLocked ?? false;
    _contents = c != null ? List<String>.from(c.contents) : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _chapterNumberController.dispose();
    _priceController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  /// Thêm trang ảnh đơn lẻ
  void _addImageUrl() {
    final url = _newImageUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập URL hình ảnh hợp lệ'),
          backgroundColor: Color(0xFFD63031),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _contents.add(url);
      _newImageUrlController.clear();
      _contentsError = null;
    });
  }

  /// Hộp thoại thêm nhiều URL ảnh một lúc (Batch Import / Upload)
  Future<void> _showBatchAddDialog() async {
    final batchController = TextEditingController();
    final theme = Theme.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.playlist_add_rounded, color: Color(0xFF6C5CE7), size: 26),
            SizedBox(width: 10),
            Text('Tải lên nhiều trang ảnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dán danh sách các đường dẫn (URL) hình ảnh vào đây. Mỗi dòng một đường dẫn:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: batchController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'https://example.com/page1.jpg\nhttps://example.com/page2.jpg\nhttps://example.com/page3.jpg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, batchController.text),
            child: const Text('Thêm vào chương'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final lines = result.split('\n');
      final validUrls = lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && (l.startsWith('http://') || l.startsWith('https://')))
          .toList();

      if (validUrls.isNotEmpty) {
        setState(() {
          _contents.addAll(validUrls);
          _contentsError = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm thành công ${validUrls.length} trang ảnh mới!'),
              backgroundColor: const Color(0xFF00B894),
            ),
          );
        }
      }
    }
  }

  /// Xóa trang ảnh khỏi danh sách
  void _removeImageAt(int index) {
    setState(() {
      _contents.removeAt(index);
    });
  }

  /// Di chuyển trang ảnh lên trên
  void _moveImageUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _contents.removeAt(index);
        _contents.insert(index - 1, item);
      });
    }
  }

  /// Di chuyển trang ảnh xuống dưới
  void _moveImageDown(int index) {
    if (index < _contents.length - 1) {
      setState(() {
        final item = _contents.removeAt(index);
        _contents.insert(index + 1, item);
      });
    }
  }

  /// Lưu chương (Create hoặc Edit)
  Future<void> _submit() async {
    // 1. Kiểm tra phân quyền: Chỉ Nhân viên (Staff) mới có quyền tạo / sửa chương
    final user = AuthService.instance.currentUser;
    if (user.role != UserRole.staff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quyền bị từ chối: Chỉ Nhân viên (Staff) mới có quyền thực hiện thao tác này!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    // 2. Validate Form
    if (!_formKey.currentState!.validate()) return;

    // 3. Validate danh sách ảnh
    if (_contents.isEmpty) {
      setState(() {
        _contentsError = 'Chương truyện bắt buộc phải có ít nhất 1 trang hình ảnh!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chương truyện bắt buộc phải có ít nhất 1 trang hình ảnh!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    final int chapterNum = int.parse(_chapterNumberController.text.trim());
    final double price = double.parse(_priceController.text.trim());

    setState(() {
      _isLoading = true;
    });

    try {
      // 4. Kiểm tra trùng lặp số chương trong manga
      final isTaken = await ChapterService.instance.isChapterNumberTaken(
        widget.mangaId,
        chapterNum,
        excludeChapterId: widget.initialChapter?.id,
      );

      if (isTaken) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chương số $chapterNum đã tồn tại trong bộ truyện này. Vui lòng chọn số khác!'),
              backgroundColor: const Color(0xFFD63031),
            ),
          );
        }
        return;
      }

      final now = DateTime.now();

      if (_isEditing) {
        final updatedChapter = widget.initialChapter!.copyWith(
          title: _titleController.text.trim(),
          chapterNumber: chapterNum,
          price: price,
          isLocked: _isLocked,
          contents: List<String>.from(_contents),
          updatedAt: now,
        );
        await ChapterService.instance.updateChapter(updatedChapter);
      } else {
        final newChapter = Chapter(
          id: const Uuid().v4(),
          mangaId: widget.mangaId,
          chapterNumber: chapterNum,
          title: _titleController.text.trim(),
          contents: List<String>.from(_contents),
          createdAt: now,
          updatedAt: now,
          isLocked: _isLocked,
          price: price,
        );
        await ChapterService.instance.addChapter(newChapter);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(_isEditing ? 'Đã cập nhật thành công Chương $chapterNum!' : 'Đã tạo thành công Chương $chapterNum!'),
              ],
            ),
            backgroundColor: const Color(0xFF00B894),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            backgroundColor: const Color(0xFFD63031),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Xác nhận xóa chương (Delete Chapter)
  Future<void> _confirmDelete() async {
    final user = AuthService.instance.currentUser;
    if (user.role != UserRole.staff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ Nhân viên (Staff) mới có quyền xóa chương!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Xác nhận xóa chương', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa Chương ${widget.initialChapter?.chapterNumber} ("${widget.initialChapter?.title}") khỏi hệ thống?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
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
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Xác nhận xóa'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ChapterService.instance.softDeleteChapter(widget.mangaId, widget.initialChapter!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa chương thành công!'),
            backgroundColor: Color(0xFF00B894),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh Sửa Chương ${widget.initialChapter!.chapterNumber}' : 'Thêm / Tải Lên Chương Mới'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Xóa chương này (Staff)',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Banner thông tin quyền Staff
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0984E3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0984E3).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.badge_outlined, color: Color(0xFF0984E3), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Khu vực quản lý chương dành riêng cho Nhân Viên (Staff). Dữ liệu sẽ được lưu trữ trực tiếp vào cơ sở dữ liệu SQLite.',
                          style: TextStyle(color: Color(0xFF0984E3), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card Thông tin cơ bản
                _buildCardSection(
                  title: 'Thông Tin Chương',
                  icon: Icons.bookmark_outline_rounded,
                  isDark: isDark,
                  theme: theme,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _chapterNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số chương (Chap) *',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Bắt buộc nhập số chap';
                              }
                              final num = int.tryParse(val.trim());
                              if (num == null || num <= 0) {
                                return 'Phải là số nguyên > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Giá chương (xu / VNĐ) *',
                              prefixIcon: Icon(Icons.monetization_on_outlined),
                              helperText: '0 là miễn phí',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Bắt buộc nhập giá';
                              }
                              final p = double.tryParse(val.trim());
                              if (p == null || p < 0) {
                                return 'Giá phải >= 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề chương
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề chương *',
                        hintText: 'Nhập tên hoặc tóm tắt chương truyện...',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề chương';
                        }
                        if (val.trim().length < 2) {
                          return 'Tiêu đề phải có tối thiểu 2 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Switch Khóa chương
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161922) : const Color(0xFFF8F9FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                        ),
                      ),
                      child: SwitchListTile(
                        secondary: Icon(
                          _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: _isLocked ? const Color(0xFFE17055) : Colors.green,
                        ),
                        title: const Text('Khóa chương (VIP / Trả phí)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Độc giả cần thanh toán để mở khóa đọc chương này', style: TextStyle(fontSize: 12)),
                        value: _isLocked,
                        activeThumbColor: const Color(0xFF6C5CE7),
                        onChanged: (val) => setState(() => _isLocked = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card Quản lý Nội dung hình ảnh (Contents)
                _buildCardSection(
                  title: 'Nội Dung Hình Ảnh (${_contents.length} trang)',
                  icon: Icons.photo_library_outlined,
                  isDark: isDark,
                  theme: theme,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Sắp xếp thứ tự các trang ảnh từ trên xuống dưới theo đúng thứ tự đọc.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C5CE7),
                            side: const BorderSide(color: Color(0xFF6C5CE7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.playlist_add_rounded, size: 18),
                          label: const Text('Thêm Nhiều URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _showBatchAddDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nhập 1 URL
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newImageUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Đường dẫn (URL) trang ảnh mới',
                              hintText: 'https://example.com/page.jpg',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                            onSubmitted: (_) => _addImageUrl(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                          label: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _addImageUrl,
                        ),
                      ],
                    ),

                    if (_contentsError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _contentsError!,
                        style: const TextStyle(color: Color(0xFFD63031), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Danh sách trang ảnh
                    if (_contents.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161922) : const Color(0xFFF8F9FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text('Chưa có trang ảnh nào được tải lên.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('Nhập URL hoặc bấm "Thêm Nhiều URL" để bắt đầu', style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _contents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final imageUrl = _contents[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A1D27) : const Color(0xFFF8F9FD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Color(0xFF6C5CE7),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 50,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 50,
                                      height: 60,
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Trang ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                                      const SizedBox(height: 2),
                                      Text(imageUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Di chuyển lên',
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                  color: index > 0 ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.3),
                                  onPressed: index > 0 ? () => _moveImageUp(index) : null,
                                ),
                                IconButton(
                                  tooltip: 'Di chuyển xuống',
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                  color: index < _contents.length - 1 ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.3),
                                  onPressed: index < _contents.length - 1 ? () => _moveImageDown(index) : null,
                                ),
                                IconButton(
                                  tooltip: 'Xóa trang này',
                                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                                  onPressed: () => _removeImageAt(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // Nút Submit
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Icon(_isEditing ? Icons.save_rounded : Icons.cloud_upload_rounded, size: 22),
                    label: Text(
                      _isLoading ? 'Đang lưu vào database...' : (_isEditing ? 'Lưu Thay Đổi Chương' : 'Tải Lên & Xuất Bản Chương'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : _submit,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            children: [
              Icon(icon, color: const Color(0xFF6C5CE7), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
