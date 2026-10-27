import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class PushNotificationScreen extends StatefulWidget {
  const PushNotificationScreen({super.key});

  @override
  State<PushNotificationScreen> createState() => _PushNotificationScreenState();
}

class _PushNotificationScreenState extends State<PushNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  // Mặc định chọn tất cả ('all') theo đúng yêu cầu
  String _selectedTarget = 'all';
  bool _isSending = false;

  final List<Map<String, dynamic>> _targetOptions = [
    {
      'id': 'all',
      'label': 'Tất cả (All)',
      'subtitle': 'Bao gồm Khách (Guest), Độc giả, Staff & Admin',
      'icon': Icons.public_rounded,
      'color': const Color(0xFF6C5CE7),
    },
    {
      'id': 'user',
      'label': 'Người dùng (Users)',
      'subtitle': 'Độc giả đã đăng ký và Khách vãng lai',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF00B894),
    },
    {
      'id': 'staff',
      'label': 'Nhân viên (Staff)',
      'subtitle': 'Toàn bộ nhân sự biên tập & kiểm duyệt',
      'icon': Icons.badge_rounded,
      'color': const Color(0xFF0984E3),
    },
    {
      'id': 'admin',
      'label': 'Quản trị viên (Admin)',
      'subtitle': 'Chỉ các tài khoản quản trị tối cao',
      'icon': Icons.admin_panel_settings_rounded,
      'color': const Color(0xFFE84393),
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthService.instance.currentUser;
    if (!currentUser.role.canPushNotification) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền thực hiện tính năng này!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final title = _titleController.text.trim();
      final message = _messageController.text.trim();

      await NotificationService.instance.pushSystemNotification(
        title: title,
        message: message,
        targetAudience: _selectedTarget,
      );

      if (!mounted) return;

      final targetName = _targetOptions
          .firstWhere((e) => e['id'] == _selectedTarget)['label'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Đã phát thông báo thành công đến "$targetName"!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi thông báo: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = AuthService.instance.currentUser;

    if (!currentUser.role.canPushNotification) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quyền truy cập')),
        body: const Center(
          child: Text('Chỉ Admin hoặc Staff mới có thể sử dụng chức năng này.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gửi Thông Báo Hệ Thống',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PHẦN CHỌN ĐỐI TƯỢNG (Target Selection)
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CHỌN ĐỐI TƯỢNG NHẬN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mặc định chọn Tất cả (bao gồm cả khách chưa đăng nhập).',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Danh sách nút chọn đối tượng (Radio Cards)
              RadioGroup<String>(
                groupValue: _selectedTarget,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTarget = val);
                  }
                },
                child: Column(
                  children: _targetOptions.map((option) {
                    final isSelected = _selectedTarget == option['id'];
                    final optColor = option['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _selectedTarget = option['id'] as String;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? optColor.withValues(alpha: 0.1)
                                  : (isDark
                                      ? const Color(0xFF1E232A)
                                      : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? optColor
                                    : (isDark
                                        ? Colors.white10
                                        : Colors.grey.shade300),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: optColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    option['icon'] as IconData,
                                    color: optColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            option['label'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? optColor
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          if (option['id'] == 'all') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: optColor.withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Mặc định',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: optColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: option['id'] as String,
                                  activeColor: optColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // NỘI DUNG THÔNG BÁO
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NỘI DUNG THÔNG BÁO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Trường Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề thông báo *',
                  hintText: 'VD: Bảo trì hệ thống, Khuyến mãi nạp coins...',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E232A) : Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề thông báo';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Trường Nội dung
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Nội dung chi tiết *',
                  hintText: 'Nhập nội dung cần gửi tới người dùng...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 50.0),
                    child: Icon(Icons.message_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E232A) : Colors.white,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập nội dung chi tiết';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // Nút Xem trước và Gửi
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _handleSendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending ? 'Đang gửi thông báo...' : 'Gửi Thông Báo Ngay',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
