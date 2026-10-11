import 'package:flutter/material.dart';

import '../models/genre.dart';
import '../services/genre_service.dart';

class GenreFormScreen extends StatefulWidget {
  final Genre? genre;

  const GenreFormScreen({super.key, this.genre});

  @override
  State<GenreFormScreen> createState() => _GenreFormScreenState();
}

class _GenreFormScreenState extends State<GenreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.genre != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.genre?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await GenreService.instance.updateGenre(
          widget.genre!.id,
          _nameController.text,
        );
      } else {
        await GenreService.instance.createGenre(_nameController.text);
      }

      if (mounted) Navigator.pop(context, true);
    } on GenreServiceException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Cập nhật thể loại' : 'Thêm thể loại'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tên thể loại',
                hintText: 'Ví dụ: Mystery',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên thể loại.'
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Lưu thay đổi' : 'Tạo thể loại'),
            ),
          ],
        ),
      ),
    );
  }
}
