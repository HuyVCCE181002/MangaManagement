import 'package:flutter/material.dart';

import '../models/genre.dart';
import '../services/genre_service.dart';
import 'genre_form_screen.dart';

class GenreListScreen extends StatefulWidget {
  const GenreListScreen({super.key});

  @override
  State<GenreListScreen> createState() => _GenreListScreenState();
}

class _GenreListScreenState extends State<GenreListScreen> {
  final GenreService _service = GenreService.instance;
  List<Genre> _genres = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    setState(() => _isLoading = true);
    try {
      final genres = await _service.getGenres();
      if (mounted) setState(() => _genres = genres);
    } on GenreServiceException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({Genre? genre}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GenreFormScreen(genre: genre)),
    );
    if (changed == true) await _loadGenres();
  }

  Future<void> _confirmDelete(Genre genre) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thể loại?'),
        content: Text('Bạn có chắc muốn xóa "${genre.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    try {
      await _service.deleteGenre(genre.id);
      await _loadGenres();
      if (mounted) _showMessage('Đã xóa thể loại ${genre.name}.');
    } on GenreServiceException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thể loại')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _genres.isEmpty
              ? const Center(child: Text('Chưa có thể loại nào.'))
              : RefreshIndicator(
                  onRefresh: _loadGenres,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _genres.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.category_outlined),
                          ),
                          title: Text(genre.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Cập nhật',
                                onPressed: () => _openForm(genre: genre),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Xóa',
                                onPressed: () => _confirmDelete(genre),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thể loại'),
      ),
    );
  }
}
