import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/chapter_service.dart';
import '../services/notification_server_service.dart';

class ChapterEditScreen extends StatefulWidget {
  final Chapter chapter;

  const ChapterEditScreen({super.key, required this.chapter});

  @override
  State<ChapterEditScreen> createState() => _ChapterEditScreenState();
}

class _ChapterEditScreenState extends State<ChapterEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _chapterNumberController;
  late TextEditingController _priceController;
  late TextEditingController _newImageUrlController;

  late bool _isLocked;
  late List<String> _contents;
  bool _isLoading = false;
  String? _contentsError;

  @override
  void initState() {
    super.initState();
    final c = widget.chapter;
    _titleController = TextEditingController(text: c.title);
    _chapterNumberController = TextEditingController(text: c.chapterNumber.toString());
    _priceController = TextEditingController(text: c.price > 0 ? c.price.toStringAsFixed(0) : '0');
    _newImageUrlController = TextEditingController();

    _isLocked = c.isLocked;
    _contents = List<String>.from(c.contents);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _chapterNumberController.dispose();
    _priceController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  /// Thêm trang ảnh mới vào danh sách nội dung
  void _addImageUrl() {
    final url = _newImageUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đường dẫn (URL) hình ảnh hợp lệ'),
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

  /// Xóa trang ảnh khỏi danh sách
  void _removeImageAt(int index) {
    setState(() {
      _contents.removeAt(index);
    });
  }

  /// Di chuyển trang ảnh lên trên (tăng thứ tự ưu tiên hiển thị trước)
  void _moveImageUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _contents.removeAt(index);
        _contents.insert(index - 1, item);
      });
    }
  }

  /// Di chuyển trang ảnh xuống dưới (giảm thứ tự hiển thị)
  void _moveImageDown(int index) {
    if (index < _contents.length - 1) {
      setState(() {
        final item = _contents.removeAt(index);
        _contents.insert(index + 1, item);
      });
    }
  }

  /// Định dạng thời gian hiển thị thân thiện
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  /// Lưu dữ liệu chỉnh sửa chương
  Future<void> _submit() async {
    // 1. Kiểm tra phân quyền: Chỉ Nhân viên (Staff) mới có quyền chỉnh sửa chương
    final user = AuthService.instance.currentUser;
    if (user.role != UserRole.staff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quyền bị từ chối: Chỉ Nhân viên (Staff) mới có quyền chỉnh sửa chương!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    // 2. Kiểm tra form validation
    if (!_formKey.currentState!.validate()) return;

    // 3. Kiểm tra danh sách ảnh
    if (_contents.isEmpty) {
      setState(() {
        _contentsError = 'Chương phải có ít nhất 1 trang hình ảnh nội dung!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chương phải có ít nhất 1 trang hình ảnh nội dung!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final int chapterNum = int.parse(_chapterNumberController.text.trim());
      final double price = double.parse(_priceController.text.trim());

      final updatedChapter = widget.chapter.copyWith(
        title: _titleController.text.trim(),
        chapterNumber: chapterNum,
        price: price,
        isLocked: _isLocked,
        contents: List<String>.from(_contents),
        updatedAt: DateTime.now(), // Cập nhật ngày edit chương tự động
      );

      // Cập nhật vào SQLite và đồng bộ Cache
      await ChapterService.instance.updateChapter(updatedChapter);

      // Bắn thông báo Staff cập nhật thành công
      NotificationServerService.instance.notifyStaffChapterAction(
        staffId: AuthService.instance.currentUser.id,
        action: 'update',
        isSuccess: true,
        mangaTitle: updatedChapter.title,
        chapterNumber: updatedChapter.chapterNumber,
        mangaId: widget.chapter.mangaId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text('Đã cập nhật thành công Chương ${updatedChapter.chapterNumber}!'),
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
            content: Text('Lỗi khi cập nhật chương: $e'),
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

  /// Xác nhận xóa mềm chapter (Soft Delete)
  Future<void> _confirmSoftDelete() async {
    final user = AuthService.instance.currentUser;
    if (user.role != UserRole.staff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ Nhân viên mới có quyền thao tác này!'),
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
            Text('Xác nhận xóa mềm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa mềm Chương ${widget.chapter.chapterNumber} ("${widget.chapter.title}")? Chương này sẽ bị ẩn khỏi danh sách độc giả.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD63031),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa mềm chương'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ChapterService.instance.softDeleteChapter(widget.chapter.mangaId, widget.chapter.id);

        // Bắn thông báo Staff xóa chương thành công
        NotificationServerService.instance.notifyStaffChapterAction(
          staffId: user.id,
          action: 'delete',
          isSuccess: true,
          mangaTitle: widget.chapter.title,
          chapterNumber: widget.chapter.chapterNumber,
          mangaId: widget.chapter.mangaId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa mềm chương thành công!'),
              backgroundColor: Color(0xFF00B894),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        // Bắn thông báo Staff xóa chương thất bại
        NotificationServerService.instance.notifyStaffChapterAction(
          staffId: user.id,
          action: 'delete',
          isSuccess: false,
          mangaTitle: widget.chapter.title,
          chapterNumber: widget.chapter.chapterNumber,
          errorDetails: e.toString(),
          mangaId: widget.chapter.mangaId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xóa chương thất bại: $e'),
              backgroundColor: const Color(0xFFD63031),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chỉnh Sửa Chương ${widget.chapter.chapterNumber}'),
        actions: [
          IconButton(
            tooltip: 'Xóa mềm chương',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _confirmSoftDelete,
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
                // Header Banner thông tin vai trò
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0984E3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0984E3).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF0984E3), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Khu vực chỉnh sửa chuyên biệt dành cho Nhân Viên (Staff). Dữ liệu sẽ được cập nhật trực tiếp vào cơ sở dữ liệu SQLite.',
                          style: TextStyle(color: Color(0xFF0984E3), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card Thông tin cơ bản của Chapter
                _buildCardSection(
                  title: 'Thông Tin Chương',
                  icon: Icons.bookmark_outline_rounded,
                  isDark: isDark,
                  theme: theme,
                  children: [
                    // Số thứ tự chương & Giá
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
                              labelText: 'Giá chương (VNĐ / Xu) *',
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
                        hintText: 'Nhập tên chương truyện...',
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

                    // Switch: Khóa chương & Đã mua
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
                        subtitle: const Text('Độc giả cần thanh toán để mở khóa chương này', style: TextStyle(fontSize: 12)),
                        value: _isLocked,
                        activeThumbColor: const Color(0xFF6C5CE7),
                        onChanged: (val) => setState(() => _isLocked = val),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ngày tạo & Ngày chỉnh sửa
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTag(
                            icon: Icons.calendar_today_rounded,
                            label: 'Ngày tạo',
                            value: _formatDateTime(widget.chapter.createdAt),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTag(
                            icon: Icons.update_rounded,
                            label: 'Lần sửa cuối',
                            value: _formatDateTime(widget.chapter.updatedAt),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card Quản lý Nội dung ảnh (Contents - Theo thứ tự đọc)
                _buildCardSection(
                  title: 'Nội Dung Hình Ảnh (${_contents.length} trang)',
                  icon: Icons.photo_library_outlined,
                  isDark: isDark,
                  theme: theme,
                  children: [
                    Text(
                      'Các trang ảnh sẽ được hiển thị đúng theo thứ tự từ trên xuống dưới. Sử dụng nút mũi tên [▲] và [▼] để thay đổi thứ tự trang.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thêm URL ảnh mới
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newImageUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Đường dẫn (URL) trang ảnh mới',
                              hintText: 'https://example.com/page1.jpg',
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
                          label: const Text('Thêm Trang', style: TextStyle(fontWeight: FontWeight.bold)),
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

                    // Danh sách các trang ảnh kèm thứ tự
                    if (_contents.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161922) : const Color(0xFFF8F9FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 44, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'Chưa có trang ảnh nào trong chương này.',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Nhập URL ảnh phía trên và bấm "Thêm Trang"',
                              style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
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
                                // Số thứ tự trang
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

                                // Thumbnail xem trước
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

                                // URL text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Trang ${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        imageUrl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Nút di chuyển Lên
                                IconButton(
                                  tooltip: 'Di chuyển lên',
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                  color: index > 0 ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.3),
                                  onPressed: index > 0 ? () => _moveImageUp(index) : null,
                                ),

                                // Nút di chuyển Xuống
                                IconButton(
                                  tooltip: 'Di chuyển xuống',
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                  color: index < _contents.length - 1 ? const Color(0xFF6C5CE7) : Colors.grey.withValues(alpha: 0.3),
                                  onPressed: index < _contents.length - 1 ? () => _moveImageDown(index) : null,
                                ),

                                // Nút Xóa trang ảnh
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

                // Nút Lưu thay đổi
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
                        : const Icon(Icons.save_rounded, size: 22),
                    label: Text(
                      _isLoading ? 'Đang lưu vào database...' : 'Lưu Thay Đổi Chương',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : _submit,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Khối card bọc từng nhóm cài đặt
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

  /// Khối hiển thị nhãn ngày tháng
  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E5EE),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
