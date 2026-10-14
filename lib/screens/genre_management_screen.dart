import 'package:flutter/material.dart';
import '../models/genre.dart';
import '../services/auth_service.dart';
import '../services/genre_service.dart';

class GenreManagementScreen extends StatefulWidget {
  const GenreManagementScreen({super.key});

  @override
  State<GenreManagementScreen> createState() => _GenreManagementScreenState();
}

class _GenreManagementScreenState extends State<GenreManagementScreen> {
  final _service = GenreService.instance;
  List<Genre> _genres = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getGenres();
    if (!mounted) return;
    setState(() { _genres = items; _loading = false; });
  }

  Future<void> _edit({Genre? genre}) async {
    final controller = TextEditingController(text: genre?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(genre == null ? 'Thêm thể loại' : 'Sửa thể loại'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Tên thể loại'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Lưu')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      if (genre == null) {
        await _service.createGenre(name);
      } else {
        await _service.renameGenre(genre, name);
      }
      await _load();
      if (mounted) _message(genre == null ? 'Đã thêm thể loại.' : 'Đã cập nhật thể loại.');
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  Future<void> _delete(Genre genre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thể loại?'),
        content: Text('Xóa "${genre.name}" khỏi danh sách?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteGenre(genre);
      await _load();
      if (mounted) _message('Đã xóa thể loại.');
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').replaceFirst('FormatException: ', '');
    if (text.toLowerCase().contains('unique')) return 'Tên thể loại đã tồn tại.';
    return text;
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final canManage = AuthService.instance.currentUser.role.canEditManga;
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thể loại')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm thể loại'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _genres.isEmpty
              ? const Center(child: Text('Chưa có thể loại nào.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _genres.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.sell_outlined, color: Color(0xFF6C5CE7)),
                        title: Text(genre.name),
                        trailing: canManage
                            ? Wrap(children: [
                                IconButton(tooltip: 'Sửa', onPressed: () => _edit(genre: genre), icon: const Icon(Icons.edit_outlined)),
                                IconButton(tooltip: 'Xóa', onPressed: () => _delete(genre), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                              ])
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
