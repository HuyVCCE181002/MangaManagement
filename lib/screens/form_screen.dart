import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/manga.dart';
import '../services/services.dart';

class MangaFormScreen extends StatefulWidget {
  final Manga? initialManga;

  const MangaFormScreen({super.key, this.initialManga});

  @override
  State<MangaFormScreen> createState() => _MangaFormScreenState();
}

class _MangaFormScreenState extends State<MangaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _coverUrlController;
  late TextEditingController _totalChaptersController;
  late TextEditingController _currentChapterController;
  late TextEditingController _ratingController;
  late TextEditingController _descriptionController;

  late String _selectedGenre;
  late String _selectedStatus;

  bool get _isEditing => widget.initialManga != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initialManga;

    _titleController = TextEditingController(text: m?.title ?? '');
    _authorController = TextEditingController(text: m?.author ?? '');
    _coverUrlController = TextEditingController(
      text: m?.coverUrl ??
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
    );
    _totalChaptersController = TextEditingController(
      text: m != null ? m.totalChapters.toString() : '100',
    );
    _currentChapterController = TextEditingController(
      text: m != null ? m.currentChapter.toString() : '0',
    );
    _ratingController = TextEditingController(
      text: m != null ? m.rating.toString() : '9.0',
    );
    _descriptionController = TextEditingController(text: m?.description ?? '');

    final availableGenres = MangaService.genres.where((g) => g != 'Tất cả').toList();
    _selectedGenre = (m != null && m.genre.isNotEmpty)
        ? m.genre
        : (availableGenres.isNotEmpty ? availableGenres.first : '');
    _selectedStatus = m?.status ?? MangaService.statuses[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _coverUrlController.dispose();
    _totalChaptersController.dispose();
    _currentChapterController.dispose();
    _ratingController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final manga = Manga(
      id: widget.initialManga?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      coverUrl: _coverUrlController.text.trim(),
      genre: _selectedGenre,
      status: _selectedStatus,
      totalChapters: int.parse(_totalChaptersController.text.trim()),
      currentChapter: int.parse(_currentChapterController.text.trim()),
      rating: double.parse(_ratingController.text.trim()),
      description: _descriptionController.text.trim(),
      isFavorite: widget.initialManga?.isFavorite ?? false,
    );

    if (_isEditing) {
      await MangaService.instance.updateManga(manga);
    } else {
      await MangaService.instance.addManga(manga);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableGenres = MangaService.genres.where((g) => g != 'Tất cả').toList();
    if (_selectedGenre.isNotEmpty && !availableGenres.contains(_selectedGenre)) {
      // Truyện cũ vẫn có thể giữ thể loại đã bị xóa khỏi danh mục.
      availableGenres.add(_selectedGenre);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh Sửa Truyện' : 'Thêm Truyện Mới'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tiêu đề
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên truyện *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên truyện' : null,
            ),
            const SizedBox(height: 12),

            // Tác giả
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Tác giả *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên tác giả' : null,
            ),
            const SizedBox(height: 12),

            // Link ảnh bìa
            TextFormField(
              controller: _coverUrlController,
              decoration: const InputDecoration(labelText: 'Link ảnh bìa (Cover URL)'),
            ),
            const SizedBox(height: 12),

            // Thể loại và Trạng thái
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGenre,
                    decoration: const InputDecoration(labelText: 'Thể loại'),
                    dropdownColor: const Color(0xFF1E212D),
                    items: availableGenres
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGenre = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    dropdownColor: const Color(0xFF1E212D),
                    items: MangaService.statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s == 'Ongoing' ? 'Đang ra' : 'Hoàn thành'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Số chapter và Chapter hiện tại
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalChaptersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tổng số chap *'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 1) ? 'Nhập số chap > 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _currentChapterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Đang đọc đến chap'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 0) ? 'Nhập số chap >= 0' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Điểm đánh giá
            TextFormField(
              controller: _ratingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Điểm đánh giá (0 - 10) *'),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                return (d == null || d < 0 || d > 10) ? 'Nhập điểm từ 0.0 - 10.0' : null;
              },
            ),
            const SizedBox(height: 12),

            // Mô tả
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Tóm tắt nội dung'),
            ),
            const SizedBox(height: 24),

            // Nút Lưu
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _submit,
              child: Text(
                _isEditing ? 'Lưu Thay Đổi' : 'Thêm Truyện',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
