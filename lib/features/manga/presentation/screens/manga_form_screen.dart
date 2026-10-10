import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/manga.dart';
import '../providers/manga_provider.dart';

class MangaFormScreen extends StatefulWidget {
  final Manga? initialManga;

  const MangaFormScreen({super.key, this.initialManga});

  @override
  State<MangaFormScreen> createState() => _MangaFormScreenState();
}

class _MangaFormScreenState extends State<MangaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _originalTitleController;
  late TextEditingController _authorController;
  late TextEditingController _artistController;
  late TextEditingController _coverUrlController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalChaptersController;
  late TextEditingController _currentChapterController;
  late TextEditingController _ratingController;
  late TextEditingController _yearController;

  late String _selectedStatus;
  late List<String> _selectedGenres;
  bool _isSaving = false;

  bool get _isEditing => widget.initialManga != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initialManga;

    _titleController = TextEditingController(text: m?.title ?? '');
    _originalTitleController = TextEditingController(text: m?.originalTitle ?? '');
    _authorController = TextEditingController(text: m?.author ?? '');
    _artistController = TextEditingController(text: m?.artist ?? '');
    _coverUrlController = TextEditingController(
      text: m?.coverUrl ?? AppConstants.defaultCoverUrl,
    );
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _totalChaptersController = TextEditingController(
      text: m != null ? m.totalChapters.toString() : '50',
    );
    _currentChapterController = TextEditingController(
      text: m != null ? m.currentChapter.toString() : '0',
    );
    _ratingController = TextEditingController(
      text: m != null ? m.rating.toString() : '8.5',
    );
    _yearController = TextEditingController(
      text: m != null ? m.releaseYear.toString() : DateTime.now().year.toString(),
    );

    _selectedStatus = m?.status ?? 'Ongoing';
    _selectedGenres = m != null ? List<String>.from(m.genres) : ['Action', 'Fantasy'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _originalTitleController.dispose();
    _authorController.dispose();
    _artistController.dispose();
    _coverUrlController.dispose();
    _descriptionController.dispose();
    _totalChaptersController.dispose();
    _currentChapterController.dispose();
    _ratingController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một thể loại!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<MangaProvider>();
    final now = DateTime.now();

    final manga = Manga(
      id: widget.initialManga?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      originalTitle: _originalTitleController.text.trim().isEmpty
          ? null
          : _originalTitleController.text.trim(),
      author: _authorController.text.trim(),
      artist: _artistController.text.trim().isEmpty
          ? null
          : _artistController.text.trim(),
      description: _descriptionController.text.trim(),
      coverUrl: _coverUrlController.text.trim().isEmpty
          ? AppConstants.defaultCoverUrl
          : _coverUrlController.text.trim(),
      genres: _selectedGenres,
      status: _selectedStatus,
      totalChapters: int.parse(_totalChaptersController.text.trim()),
      currentChapter: int.parse(_currentChapterController.text.trim()),
      rating: double.parse(_ratingController.text.trim()),
      releaseYear: int.parse(_yearController.text.trim()),
      updatedAt: now,
    );

    final success = _isEditing
        ? await provider.updateManga(manga)
        : await provider.addManga(manga);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Đã cập nhật thông tin truyện!' : 'Đã thêm truyện mới thành công!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, manga);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Thao tác thất bại!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh Sửa Truyện' : 'Thêm Truyện Mới'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Preview Image Card
            _buildImagePreview(),
            const SizedBox(height: 20),

            // Form Fields
            CustomTextField(
              controller: _titleController,
              label: 'Tên truyện *',
              hint: 'Ví dụ: Solo Leveling',
              prefixIcon: Icons.menu_book_rounded,
              validator: (v) => Validators.required(v, 'Tên truyện'),
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _originalTitleController,
              label: 'Tên gốc (nếu có)',
              hint: 'Ví dụ: 나 혼자만 레벨업 hoặc ワンピース',
              prefixIcon: Icons.translate_rounded,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _authorController,
                    label: 'Tác giả *',
                    hint: 'Ví dụ: Chugong',
                    prefixIcon: Icons.person_rounded,
                    validator: (v) => Validators.required(v, 'Tác giả'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _artistController,
                    label: 'Họa sĩ minh họa',
                    hint: 'Ví dụ: DUBU',
                    prefixIcon: Icons.brush_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _coverUrlController,
              label: 'Đường dẫn ảnh bìa (Cover URL)',
              hint: 'https://...',
              prefixIcon: Icons.link_rounded,
              validator: Validators.validUrl,
            ),
            const SizedBox(height: 16),

            // Trạng thái phát hành
            const Text(
              'Trạng thái phát hành *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  items: AppConstants.mangaStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'Ongoing'
                            ? 'Đang phát hành (Ongoing)'
                            : status == 'Completed'
                                ? 'Đã hoàn thành (Completed)'
                                : 'Tạm dừng (Hiatus)',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thể loại (Multiple Chip selection)
            const Text(
              'Thể loại (Chọn ít nhất 1) *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.availableGenres.map((genre) {
                final isSelected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppColors.surfaceVariant,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Chương và đánh giá
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _totalChaptersController,
                    label: 'Tổng số tập/chap *',
                    hint: '100',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.layers_rounded,
                    validator: (v) => Validators.positiveNumber(v, 'Tổng số chap'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _currentChapterController,
                    label: 'Đang đọc đến chap',
                    hint: '0',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.bookmark_border_rounded,
                    validator: (v) => Validators.positiveNumber(v, 'Chap hiện tại'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _ratingController,
                    label: 'Điểm đánh giá (0-10) *',
                    hint: '9.0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.star_border_rounded,
                    validator: Validators.rating,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _yearController,
                    label: 'Năm phát hành',
                    hint: '2023',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.calendar_today_rounded,
                    validator: (v) => Validators.positiveNumber(v, 'Năm phát hành'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _descriptionController,
              label: 'Tóm tắt nội dung cốt truyện',
              hint: 'Nhập mô tả chi tiết nội dung truyện...',
              maxLines: 4,
            ),
            const SizedBox(height: 28),

            CustomButton(
              label: _isEditing ? 'Lưu Thay Đổi' : 'Thêm Vào Thư Viện',
              icon: _isEditing ? Icons.save_rounded : Icons.add_circle_outline_rounded,
              isLoading: _isSaving,
              onPressed: _submitForm,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _coverUrlController,
        builder: (context, value, child) {
          final url = value.text.trim();
          if (url.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 40, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'Xem trước ảnh bìa truyện',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Text(
                    'Đường dẫn ảnh không hợp lệ',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Xem trước ảnh bìa',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
