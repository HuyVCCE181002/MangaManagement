import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Danh sách avatar mẫu phong cách Manga / Anime chất lượng cao
class PresetAvatar {
  final String name;
  final String url;

  const PresetAvatar({required this.name, required this.url});
}

const List<PresetAvatar> kPresetAvatars = [
  PresetAvatar(
    name: 'Luffy Mũ Rơm',
    url: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Sung Jinwoo',
    url: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Frieren Pháp Sư',
    url: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Gojo Satoru',
    url: 'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Anya Forger',
    url: 'https://images.unsplash.com/photo-1563089145-599997674d42?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Isagi Yoichi',
    url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Roronoa Zoro',
    url: 'https://images.unsplash.com/photo-1569701813229-33284b643e3c?w=400&auto=format&fit=crop&q=80',
  ),
  PresetAvatar(
    name: 'Cyber Samurai',
    url: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=400&auto=format&fit=crop&q=80',
  ),
];

// ============================================================================
// 1. EDIT PROFILE DIALOG (Cập nhật tên hiển thị)
// ============================================================================
class EditProfileDialog extends StatefulWidget {
  final AppUser user;

  const EditProfileDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, AppUser user) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditProfileDialog(user: user),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final res = await AuthService.instance.updateProfile(
      displayName: _nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF262A3B) : const Color(0xFFE2E5EE)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Color(0xFF6C5CE7), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Chỉnh Sửa Hồ Sơ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tài khoản đăng nhập: @${widget.user.username}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Tên hiển thị
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Tên hiển thị (Biệt danh) *',
                    hintText: 'Nhập biệt danh của bạn...',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6C5CE7)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Tên hiển thị không được để trống';
                    if (v.trim().length < 2) return 'Tên hiển thị phải có ít nhất 2 ký tự';
                    if (v.trim().length > 50) return 'Tên hiển thị không được vượt quá 50 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // Nút hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. AVATAR PICKER DIALOG (Upload / Đổi Avatar từ Preset hoặc Custom URL)
// ============================================================================
class AvatarPickerDialog extends StatefulWidget {
  final AppUser user;

  const AvatarPickerDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, AppUser user) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AvatarPickerDialog(user: user),
    );
  }

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  final _urlController = TextEditingController();
  String? _selectedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.user.avatarUrl;
    if (_selectedUrl != null && !kPresetAvatars.any((a) => a.url == _selectedUrl)) {
      _urlController.text = _selectedUrl!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleApply(String? avatarUrl) async {
    setState(() => _isLoading = true);

    final res = await AuthService.instance.updateAvatar(avatarUrl);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF262A3B) : const Color(0xFFE2E5EE)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_circle_rounded, color: Color(0xFF00B894), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Đổi Ảnh Đại Diện',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview avatar hiện tại
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF6C5CE7), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _selectedUrl != null && _selectedUrl!.isNotEmpty
                                    ? Image.network(
                                        _selectedUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(
                                          widget.user.role.icon,
                                          size: 44,
                                          color: widget.user.role.color,
                                        ),
                                      )
                                    : Container(
                                        color: widget.user.role.color.withValues(alpha: 0.2),
                                        child: Icon(
                                          widget.user.role.icon,
                                          size: 44,
                                          color: widget.user.role.color,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ảnh xem trước (Preview)',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Phần 1: Chọn avatar anime có sẵn
                      Text(
                        'BỘ SƯU TẬP AVATAR MANGA CÓ SẴN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: kPresetAvatars.length,
                        itemBuilder: (context, index) {
                          final preset = kPresetAvatars[index];
                          final isPicked = _selectedUrl == preset.url;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedUrl = preset.url;
                                _urlController.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isPicked ? const Color(0xFF00B894) : Colors.transparent,
                                  width: isPicked ? 3 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(preset.url, fit: BoxFit.cover),
                                    if (isPicked)
                                      Container(
                                        color: const Color(0xFF00B894).withValues(alpha: 0.3),
                                        child: const Center(
                                          child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Phần 2: Nhập Custom URL
                      Text(
                        'HOẶC DÁN ĐƯỜNG DẪN ẢNH CỦA BẠN (CUSTOM URL)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _urlController,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/my-avatar.jpg',
                          prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF6C5CE7)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_rounded, color: Color(0xFF00B894)),
                            tooltip: 'Áp dụng link ảnh',
                            onPressed: () {
                              final text = _urlController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() => _selectedUrl = text);
                              }
                            },
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty) {
                            setState(() => _selectedUrl = val.trim());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nút hành động
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Gỡ avatar', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleApply(null),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _handleApply(_selectedUrl),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B894),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Lưu Avatar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. CHANGE PASSWORD DIALOG (Đổi mật khẩu)
// ============================================================================
class ChangePasswordDialog extends StatefulWidget {
  final AppUser user;

  const ChangePasswordDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, AppUser user) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ChangePasswordDialog(user: user),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu mới xác nhận không khớp!'),
          backgroundColor: Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await AuthService.instance.changePassword(
      currentPassword: _currentPasswordController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF262A3B) : const Color(0xFFE2E5EE)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE17055).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFE17055), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Đổi Mật Khẩu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Mật khẩu hiện tại
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại *',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6C5CE7)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                ),
                const SizedBox(height: 14),

                // Mật khẩu mới
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew = _obscureNew,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới *',
                    prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF6C5CE7)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mật khẩu mới';
                    if (v.trim().length < 4) return 'Mật khẩu mới tối thiểu 4 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Xác nhận mật khẩu mới
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận lại mật khẩu mới *',
                    prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF6C5CE7)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng xác nhận lại mật khẩu' : null,
                ),
                const SizedBox(height: 22),

                // Nút hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Đổi Mật Khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. USER DELETE ACCOUNT DIALOG (Người dùng tự xóa tài khoản của mình)
// ============================================================================
class UserDeleteAccountDialog extends StatefulWidget {
  final AppUser user;

  const UserDeleteAccountDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, AppUser user) {
    return showDialog<bool>(
      context: context,
      builder: (_) => UserDeleteAccountDialog(user: user),
    );
  }

  @override
  State<UserDeleteAccountDialog> createState() => _UserDeleteAccountDialogState();
}

class _UserDeleteAccountDialogState extends State<UserDeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final res = await AuthService.instance.deleteCurrentAccount(
      confirmPassword: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Xóa Tài Khoản Cá Nhân',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.redAccent),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có chắc chắn muốn xóa vĩnh viễn tài khoản @${widget.user.username} (${widget.user.displayName})?',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('⚠️ Cảnh báo quan trọng:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• Ví coins và toàn bộ số dư sẽ bị hủy bỏ.', style: TextStyle(fontSize: 12)),
                    Text('• Danh sách truyện yêu thích và bookmark sẽ bị xóa.', style: TextStyle(fontSize: 12)),
                    Text('• Hành động này không thể hoàn tác!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nhập mật khẩu hiện tại để xác nhận:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu của bạn *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.redAccent),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mật khẩu để xác nhận' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Xác nhận xóa tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isLoading ? null : _handleDelete,
        ),
      ],
    );
  }
}
