import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/manga.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import '../services/genre_service.dart';
import '../services/notification_server_service.dart';

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
  List<String> _availableGenres = List<String>.from(MangaService.genres.where((g) => g != 'Tất cả'));

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

    _selectedGenre = (m != null && m.genre.isNotEmpty) ? m.genre : MangaService.genres[1];
    _selectedStatus = m?.status ?? MangaService.statuses[0];
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await GenreService.instance.getGenres();
    if (!mounted || genres.isEmpty) return;
    setState(() {
      _availableGenres = genres.map((genre) => genre.name).toList();
      if (!_availableGenres.contains(_selectedGenre)) _selectedGenre = _availableGenres.first;
    });
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
    final user = AuthService.instance.currentUser;
    if (!user.role.canAddManga) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền thực hiện thao tác này. Cần quyền Staff hoặc Admin!'),
          backgroundColor: Color(0xFFD63031),
        ),
      );
      return;
    }

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
      isHidden: widget.initialManga?.isHidden ?? false,
    );

    if (_isEditing) {
      await MangaService.instance.updateManga(manga);
      // Bắn thông báo cập nhật truyện cho những người đã yêu thích truyện
      NotificationServerService.instance.notifyMangaUpdated(
        mangaId: manga.id,
        mangaTitle: manga.title,
      );
    } else {
      await MangaService.instance.addManga(manga);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableGenres = _availableGenres;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh Sửa Truyện' : 'Thêm Truyện Mới'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Tiêu đề
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Tên truyện *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên truyện' : null,
                ),
                const SizedBox(height: 14),

                // Tác giả
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(labelText: 'Tác giả *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên tác giả' : null,
                ),
                const SizedBox(height: 14),

                // Link ảnh bìa
                TextFormField(
                  controller: _coverUrlController,
                  decoration: const InputDecoration(labelText: 'Link ảnh bìa (Cover URL)'),
                ),
                const SizedBox(height: 14),

                // Thể loại và Trạng thái
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGenre,
                        decoration: const InputDecoration(labelText: 'Thể loại'),
                        dropdownColor: theme.cardColor,
                        items: availableGenres
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGenre = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Trạng thái'),
                        dropdownColor: theme.cardColor,
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
                const SizedBox(height: 14),

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
                    const SizedBox(width: 14),
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
                const SizedBox(height: 14),

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
                const SizedBox(height: 14),

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
        ),
      ),
    );
  }
}
