import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialUsername;

  const ForgotPasswordScreen({super.key, this.initialUsername});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRequestingOtp = false;
  bool _isResetting = false;

  String? _generatedOtp;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên đăng nhập để nhận mã OTP!'),
          backgroundColor: Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isRequestingOtp = true);

    final res = await AuthService.instance.requestPasswordReset(username);

    setState(() => _isRequestingOtp = false);

    if (!mounted) return;

    if (res.success && res.otp != null) {
      setState(() {
        _generatedOtp = res.otp;
        _otpSent = true;
        _otpController.text = res.otp!; // Tự động điền luôn để trải nghiệm mượt mà
      });

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

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu xác nhận không trùng khớp!'),
          backgroundColor: Color(0xFFD63031),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isResetting = true);

    final res = await AuthService.instance.verifyOtpAndResetPassword(
      username: _usernameController.text.trim(),
      otp: _otpController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    setState(() => _isResetting = false);

    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF00B894),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Trả lại tên đăng nhập cho LoginScreen để pre-fill
      Navigator.pop(context, _usernameController.text.trim());
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên Mật Khẩu'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Chuyển sang Chế độ Sáng' : 'Chuyển sang Chế độ Tối',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : const Color(0xFF6C5CE7),
            ),
            onPressed: () => ThemeService.instance.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Khóa bảo mật
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE17055).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Đặt Lại Mật Khẩu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nhập tên tài khoản của bạn để nhận mã xác thực OTP và đổi mật khẩu mới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Phần 1: Nhập Username & Nút Gửi OTP
                    Text(
                      'BƯỚC 1: XÁC THỰC TÀI KHOẢN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: const Color(0xFF6C5CE7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Tên đăng nhập',
                        hintText: 'Nhập admin, staff, reader...',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6C5CE7)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập' : null,
                    ),
                    const SizedBox(height: 10),

                    // Nút Lấy mã OTP
                    OutlinedButton.icon(
                      onPressed: _isRequestingOtp ? null : _handleRequestOtp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C5CE7),
                        side: const BorderSide(color: Color(0xFF6C5CE7)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isRequestingOtp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C5CE7)),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _otpSent ? 'Gửi lại mã OTP mới' : 'Lấy mã xác thực OTP',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),

                    // Hộp thông báo mã OTP đã tạo (Mô phỏng tiện lợi)
                    if (_otpSent && _generatedOtp != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mã OTP mô phỏng cho tài khoản ${_usernameController.text}:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _generatedOtp!,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                  color: Color(0xFF00B894),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đã tự động điền vào ô mã OTP bên dưới. Hiệu lực trong 5 phút.',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Phần 2: Điền OTP & Mật khẩu mới
                    Text(
                      'BƯỚC 2: NHẬP OTP & ĐẶT MẬT KHẨU MỚI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: const Color(0xFF6C5CE7),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mã OTP
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Mã xác thực OTP (6 số)',
                        prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF6C5CE7)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mã OTP';
                        if (v.trim().length != 6) return 'Mã OTP gồm 6 chữ số';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mật khẩu mới
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6C5CE7)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mật khẩu mới';
                        if (v.trim().length < 4) return 'Mật khẩu phải có ít nhất 4 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Xác nhận mật khẩu mới
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF6C5CE7)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF161924) : const Color(0xFFE9EDF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng xác nhận mật khẩu mới';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),

                    // Nút Đổi mật khẩu
                    ElevatedButton(
                      onPressed: _isResetting ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      child: _isResetting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Xác Nhận Đổi Mật Khẩu',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Nút Quay lại Đăng nhập
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Quay lại Đăng nhập'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
